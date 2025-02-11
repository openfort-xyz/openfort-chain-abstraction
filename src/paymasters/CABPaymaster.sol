// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "account-abstraction/core/BasePaymaster.sol";
import "account-abstraction/core/UserOperationLib.sol";
import "account-abstraction/core/Helpers.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";
import {LibTokens} from "./LibTokens.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title CABPaymaster
 * @dev A paymaster used in chain abstracted balance to sponsor the gas fee and tokens cross-chain.
 */
contract CABPaymaster is BasePaymaster, Initializable {
    using SafeERC20 for IERC20;
    using UserOperationLib for PackedUserOperation;
    using LibTokens for LibTokens.TokensStore;

    LibTokens.TokensStore private tokensStore;
    IInvoiceManager public immutable invoiceManager;
    address public immutable verifyingSigner;

    uint256 private constant VALID_TIMESTAMP_OFFSET = PAYMASTER_DATA_OFFSET;
    uint256 private constant SIGNATURE_OFFSET = VALID_TIMESTAMP_OFFSET + 12;

    address public constant ENTRY_POINT_V7 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    constructor(IInvoiceManager _invoiceManager, address _verifyingSigner, address _owner)
        BasePaymaster(IEntryPoint(ENTRY_POINT_V7), _owner)
    {
        invoiceManager = _invoiceManager;
        verifyingSigner = _verifyingSigner;
    }

    function initialize(address[] memory _supportedTokens) public initializer {
        for (uint256 i = 0; i < _supportedTokens.length; ++i) {
            tokensStore.addSupportedToken(_supportedTokens[i]);
        }
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        LibTokens.withdraw(owner(), token, amount);
    }

    function getHash(PackedUserOperation calldata userOp, uint48 validUntil, uint48 validAfter)
        public
        view
        returns (bytes32)
    {
        // can't use userOp.hash(), since it contains also the paymasterAndData itself.
        address sender = userOp.getSender();
        (,, bytes calldata signature) = parsePaymasterAndData(userOp.paymasterAndData);

        (bytes calldata repayTokenData, bytes calldata sponsorTokenData,) = parsePaymasterSignature(signature);

        return keccak256(
            abi.encode(
                sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                keccak256(abi.encode(repayTokenData, sponsorTokenData)),
                bytes32(userOp.paymasterAndData[PAYMASTER_VALIDATION_GAS_OFFSET:PAYMASTER_DATA_OFFSET]),
                userOp.preVerificationGas,
                userOp.gasFees,
                block.chainid,
                address(this),
                validUntil,
                validAfter
            )
        );
    }

    function _validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 requiredPreFund)
        internal
        override
        returns (bytes memory context, uint256 validationData)
    {
        (requiredPreFund);
        address sender = userOp.getSender();
        (uint48 validUntil, uint48 validAfter, bytes calldata signature) =
            parsePaymasterAndData(userOp.paymasterAndData);

        (bytes calldata repayTokenData, bytes calldata sponsorTokenData, bytes memory paymasterSignature) =
            parsePaymasterSignature(signature);

        (uint256 sponsorTokenLength, IPaymasterVerifier.SponsorToken[] memory sponsorTokens) =
            parseSponsorTokenData(sponsorTokenData);

        // revoke the approval at the end of userOp
        for (uint256 i = 0; i < sponsorTokenLength; ++i) {
            address token = sponsorTokens[i].token;
            if (token == LibTokens.NATIVE_TOKEN) {
                (bool success,) = payable(sponsorTokens[i].spender).call{value: sponsorTokens[i].amount}("");
                require(success, "Native token transfer failed");
            } else {
                IERC20(sponsorTokens[i].token).approve(sponsorTokens[i].spender, sponsorTokens[i].amount);
            }
        }

        bytes32 invoiceId =
            invoiceManager.getInvoiceId(sender, address(this), userOp.nonce, block.chainid, repayTokenData);

        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(getHash(userOp, validUntil, validAfter));

        // don't revert on signature failure: return SIG_VALIDATION_FAILED
        if (verifyingSigner != ECDSA.recover(hash, paymasterSignature)) {
            return (
                abi.encodePacked(invoiceId, sender, userOp.nonce, sponsorTokenData[0:1 + sponsorTokenLength * 72]),
                _packValidationData(true, validUntil, validAfter)
            );
        }
        return (
            abi.encodePacked(invoiceId, sender, userOp.nonce, sponsorTokenData[0:1 + sponsorTokenLength * 72]),
            _packValidationData(false, validUntil, validAfter)
        );
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256 actualUserOpFeePerGas)
        internal
        virtual
        override
    {
        bytes calldata sponsorTokenData = context[84:];

        (uint8 sponsorTokenLength, IPaymasterVerifier.SponsorToken[] memory sponsorTokens) =
            parseSponsorTokenData(sponsorTokenData);
        for (uint8 i = 0; i < sponsorTokenLength; ++i) {
            address token = sponsorTokens[i].token;
            if (token != LibTokens.NATIVE_TOKEN) {
                require(IERC20(token).approve(sponsorTokens[i].spender, 0), "CABPaymaster: Reset approval failed");
            }
        }
        // TODO: Batch Proving Optimistation -> write in settlement contract on `opSucceeded`
        if (mode == PostOpMode.opSucceeded) {
            invoiceManager.createInvoice(
                uint256(bytes32(context[52:84])), // nonce
                address(bytes20(context[32:52])), // account
                bytes32(context[:32]) // invoice id
            );
        }
    }

    function parsePaymasterAndData(bytes calldata paymasterAndData)
        public
        pure
        returns (uint48 validUntil, uint48 validAfter, bytes calldata signature)
    {
        validUntil = uint48(bytes6(paymasterAndData[VALID_TIMESTAMP_OFFSET:VALID_TIMESTAMP_OFFSET + 6]));
        validAfter = uint48(bytes6(paymasterAndData[VALID_TIMESTAMP_OFFSET + 6:VALID_TIMESTAMP_OFFSET + 12]));
        signature = paymasterAndData[SIGNATURE_OFFSET:];
    }

    function parsePaymasterSignature(bytes calldata signature)
        public
        pure
        returns (bytes calldata repayTokenData, bytes calldata sponsorTokenData, bytes calldata paymasterSignature)
    {
        // casting to uint16 to avoid overflow in future calculation
        uint16 repayTokenLength = uint16(uint8(bytes1(signature[0])));
        uint16 sponsorTokenLength = uint16(uint8(bytes1(signature[repayTokenLength * 84 + 1])));

        // repayTokenData[]
        // 1 byte: length
        // length * 84 bytes: (20 bytes: vault address + 32 bytes chainID + 32 bytes amount)

        // sponsorTokenData[]
        // 1 byte: length
        // length * 72 bytes: (20 bytes: token adddress + 20 bytes: spender address + 32 bytes: amount)

        require(
            signature.length == 1 + repayTokenLength * 84 + 1 + sponsorTokenLength * 72 + 65,
            "CABPaymaster: invalid paymasterAndData"
        );

        repayTokenData = signature[0:1 + repayTokenLength * 84];
        sponsorTokenData = signature[1 + repayTokenLength * 84:1 + repayTokenLength * 84 + 1 + sponsorTokenLength * 72];
        paymasterSignature = signature[
            1 + repayTokenLength * 84 + 1 + sponsorTokenLength * 72:
                1 + repayTokenLength * 84 + 1 + sponsorTokenLength * 72 + 65
        ];
    }

    function parseSponsorTokenData(bytes calldata sponsorTokenData)
        public
        pure
        returns (uint8 sponsorTokenLength, IPaymasterVerifier.SponsorToken[] memory sponsorTokens)
    {
        sponsorTokenLength = uint8(bytes1(sponsorTokenData[0]));

        // 1 byte: length
        // length * 72 bytes: (20 bytes: token adddress + 20 bytes: spender address + 32 bytes: amount)
        require(sponsorTokenData.length == 1 + sponsorTokenLength * 72, "CABPaymaster: invalid sponsorTokenData length");

        sponsorTokens = new IPaymasterVerifier.SponsorToken[](sponsorTokenLength);
        for (uint256 i = 0; i < uint256(sponsorTokenLength); ++i) {
            uint256 offset = 1 + i * 72;
            sponsorTokens[i] = IPaymasterVerifier.SponsorToken(
                address(bytes20(sponsorTokenData[offset:offset + 20])),
                address(bytes20(sponsorTokenData[offset + 20:offset + 40])),
                uint256(bytes32(sponsorTokenData[offset + 40:offset + 72]))
            );
        }
    }

    function addSupportedToken(address token) public onlyOwner {
        tokensStore.addSupportedToken(token);
        emit LibTokens.SupportedTokenAdded(token);
    }

    function removeSupportedToken(address token) public onlyOwner {
        tokensStore.removeSupportedToken(token);
        emit LibTokens.SupportedTokenRemoved(token);
    }

    function getSupportedTokens() public view returns (address[] memory) {
        return tokensStore.getSupportedTokens();
    }

    receive() external payable {}
}

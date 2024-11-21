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
import {IVault} from "../interfaces/IVault.sol";
import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";

/**
 * @title CABPaymaster
 * @dev A paymaster used in chain abstracted balance to sponsor the gas fee and tokens cross-chain.
 */
contract CABPaymaster is IPaymasterVerifier, BasePaymaster {
    using SafeERC20 for IERC20;
    using UserOperationLib for PackedUserOperation;

    IInvoiceManager public immutable invoiceManager;

    address public immutable verifyingSigner;

    uint256 private constant VALID_TIMESTAMP_OFFSET = PAYMASTER_DATA_OFFSET;

    uint256 private constant SIGNATURE_OFFSET = VALID_TIMESTAMP_OFFSET + 64;

    constructor(IEntryPoint _entryPoint, IInvoiceManager _invoiceManager, address _verifyingSigner)
        BasePaymaster(_entryPoint, _verifyingSigner)
    {
        invoiceManager = _invoiceManager;
        verifyingSigner = _verifyingSigner;
    }

    /// @inheritdoc IPaymasterVerifier
    function verifyInvoice(
        bytes32 invoiceId,
        IInvoiceManager.InvoiceWithRepayTokens calldata invoice,
        bytes calldata proof
    ) external virtual override returns (bool ret) {
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(getInvoiceHash(invoice));
        if (verifyingSigner == ECDSA.recover(hash, proof)) {
            ret = true;
        }
    }

    function withdraw(address token, uint256 amount) external override {
        IERC20(token).safeTransfer(owner(), amount);
    }

    function getInvoiceHash(IInvoiceManager.InvoiceWithRepayTokens calldata invoice) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                invoice.account,
                invoice.nonce,
                invoice.paymaster,
                invoice.sponsorChainId,
                keccak256(abi.encode(invoice.repayTokenInfos)) // vault, amount, chain
            )
        );
    }

    function getHash(PackedUserOperation calldata userOp, uint48 validUntil, uint48 validAfter)
        public
        view
        returns (bytes32)
    {
        // can't use userOp.hash(), since it contains also the paymasterAndData itself.
        address sender = userOp.getSender();
        (,, bytes calldata signature) = parsePaymasterAndData(userOp.paymasterAndData);
        (bytes calldata tokenData,) = parsePaymasterSignature(signature);

        return keccak256(
            abi.encode(
                sender,
                userOp.nonce,
                keccak256(userOp.initCode),
                keccak256(userOp.callData),
                userOp.accountGasLimits,
                keccak256(tokenData), // SponsorToken[]
                uint256(bytes32(userOp.paymasterAndData[PAYMASTER_VALIDATION_GAS_OFFSET:PAYMASTER_DATA_OFFSET])),
                userOp.preVerificationGas,
                userOp.gasFees,
                block.chainid,
                address(this),
                validUntil,
                validAfter
            )
        );
    }

    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32, /*userOpHash*/
        uint256 requiredPreFund
    ) internal override returns (bytes memory context, uint256 validationData) {
        (requiredPreFund);

        (uint48 validUntil, uint48 validAfter, bytes calldata signature) =
            parsePaymasterAndData(userOp.paymasterAndData);

        (bytes calldata sponsorTokenData, bytes memory paymasterSignature) = parsePaymasterSignature(signature);
        (uint256 sponsorTokenLength, SponsorToken[] memory sponsorTokens) = parseSponsorTokenData(sponsorTokenData);

        // revoke the approval at the end of userOp
        for (uint256 i = 0; i < sponsorTokenLength; i++) {
            SponsorToken memory sponsorToken = sponsorTokens[i];
            // if (sponsorToken.token == ETH) {
            //     // check that calldata contains `withdrawGasExcess`
            //     balances[spender] += amount
            //     continue;
            // }
            IERC20(sponsorToken.token).approve(sponsorToken.spender, sponsorToken.amount);
        }

        // check the invoice
        // bytes32 invoiceId = invoiceManager.getInvoiceId(userOp.sender, address(this), userOp.nonce, block.chainid, repayTokens);
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(getHash(userOp, validUntil, validAfter));

        // don't revert on signature failure: return SIG_VALIDATION_FAILED
        if (verifyingSigner != ECDSA.recover(hash, paymasterSignature)) {
            return (sponsorTokenData[0:1 + sponsorTokenLength * 72], _packValidationData(true, validUntil, validAfter));
        }

        return (sponsorTokenData[0:1 + sponsorTokenLength * 72], _packValidationData(false, validUntil, validAfter));
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256 actualUserOpFeePerGas)
        internal
        virtual
        override
    {
        (uint8 sponsorTokenLength, SponsorToken[] memory sponsorTokens) = parseSponsorTokenData(context);
        for (uint8 i = 0; i < sponsorTokenLength; i++) {
            // if (sponsorToken.token == ETH) {
            //     balances[spender] -= amount;
            //     continue;
            // }
            SponsorToken memory sponsorToken = sponsorTokens[i];
            IERC20(sponsorToken.token).approve(sponsorToken.spender, 0);
        }
    }

    function parsePaymasterAndData(bytes calldata paymasterAndData)
        public
        pure
        returns (uint48 validUntil, uint48 validAfter, bytes calldata signature)
    {
        (validUntil, validAfter) = abi.decode(paymasterAndData[VALID_TIMESTAMP_OFFSET:], (uint48, uint48));
        signature = paymasterAndData[SIGNATURE_OFFSET:];
    }

    function parsePaymasterSignature(bytes calldata signature)
        public
        pure
        returns (bytes calldata sponsorTokenData, bytes calldata paymasterSignature)
    {
        uint8 sponsorTokenLength = uint8(signature[0]);
        require(signature.length == sponsorTokenLength * 72 + 65 + 1, "CABPaymaster: invalid paymasterAndData");

        sponsorTokenData = signature[0:1 + sponsorTokenLength * 72];
        paymasterSignature = signature[sponsorTokenLength * 72 + 1:sponsorTokenLength * 72 + 66];
    }

    function parseSponsorTokenData(bytes calldata sposnorTokenData)
        public
        pure
        returns (uint8 sponsorTokenLength, SponsorToken[] memory sponsorTokens)
    {
        sponsorTokenLength = uint8(bytes1(sposnorTokenData[0]));

        // 1 byte: length
        // length * 72 bytes: (20 bytes: token adddress + 20 bytes: spender address + 32 bytes: amount)
        require(
            sposnorTokenData.length == 1 + sponsorTokenLength * (72), "CABPaymaster: invalid sponsorTokenData length"
        );

        sponsorTokens = new SponsorToken[](sponsorTokenLength);
        for (uint256 i = 0; i < uint256(sponsorTokenLength);) {
            uint256 offset = 1 + i * 72;
            address token = address(bytes20(sposnorTokenData[offset:offset + 20]));
            address spender = address(bytes20(sposnorTokenData[offset + 20:offset + 40]));
            uint256 amount = uint256(bytes32(sposnorTokenData[offset + 40:offset + 72]));

            sponsorTokens[i] = SponsorToken(token, spender, amount);

            unchecked {
                i++;
            }
        }
    }
}

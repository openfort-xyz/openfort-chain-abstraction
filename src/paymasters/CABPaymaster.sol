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
import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";
import {ILiquidityManager} from "../interfaces/ILiquidityManager.sol";
import {LibBytes} from "@solady/utils/LibBytes.sol";

/**
 * @title CABPaymaster
 * @dev A paymaster used in chain abstracted balance to sponsor the gas fee and tokens cross-chain.
 */
contract CABPaymaster is IPaymasterVerifier, BasePaymaster {
    using SafeERC20 for IERC20;
    using UserOperationLib for PackedUserOperation;

    IInvoiceManager public immutable invoiceManager;
    ICrossL2Prover public immutable crossL2Prover;
    ILiquidityManager public immutable liquidityManager;

    address public immutable verifyingSigner;

    uint256 private constant VALID_TIMESTAMP_OFFSET = PAYMASTER_DATA_OFFSET;
    uint256 private constant SIGNATURE_OFFSET = VALID_TIMESTAMP_OFFSET + 12;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(
        IEntryPoint _entryPoint,
        IInvoiceManager _invoiceManager,
        ICrossL2Prover _crossL2Prover,
        ILiquidityManager _liquidityManager,
        address _verifyingSigner,
        address _owner
    ) BasePaymaster(_entryPoint) {
        invoiceManager = _invoiceManager;
        crossL2Prover = _crossL2Prover;
        liquidityManager = _liquidityManager;
        verifyingSigner = _verifyingSigner;
        transferOwnership(_owner);
    }

    /// @inheritdoc IPaymasterVerifier
    function verifyInvoice(
        bytes32 _invoiceId,
        IInvoiceManager.InvoiceWithRepayTokens calldata _invoice,
        bytes calldata _proof
    ) external virtual override returns (bool) {
        bytes32 invoiceId = invoiceManager.getInvoiceId(
            _invoice.account,
            _invoice.paymaster,
            _invoice.nonce,
            _invoice.sponsorChainId,
            _encodeRepayToken(_invoice.repayTokenInfos)
        );

        if (invoiceId != _invoiceId) return false;

        (uint256 logIndex, bytes memory proof) = abi.decode(_proof, (uint256, bytes));
        (,, bytes[] memory topics,) = crossL2Prover.validateEvent(logIndex, proof);

        return (LibBytes.eqs(topics[0], IInvoiceManager.InvoiceCreated.selector) && LibBytes.eqs(topics[1], invoiceId));
    }

    function withdraw(address token, uint256 amount) external override onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
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

    function getInvoiceHash(IInvoiceManager.InvoiceWithRepayTokens calldata invoice) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                invoice.account,
                invoice.nonce,
                invoice.paymaster,
                invoice.sponsorChainId,
                keccak256(abi.encode(invoice.repayTokenInfos))
            )
        );
    }

    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 requiredPreFund
    ) internal virtual override returns (bytes memory context, uint256 validationData) {
        (requiredPreFund);
        address sender = userOp.getSender();
        (uint48 validUntil, uint48 validAfter, bytes calldata signature) =
            parsePaymasterAndData(userOp.paymasterAndData);

        // Verify signature
        bytes32 hash = getHash(userOp, validUntil, validAfter);
        require(verifyingSigner == ECDSA.recover(hash, signature), "CABPaymaster: INVALID_SIGNATURE");

        // Parse token data from signature
        (bytes calldata repayTokenData, bytes calldata sponsorTokenData,) = parsePaymasterSignature(signature);

        // Handle token transfers and swaps if needed
        _handleTokenOperations(repayTokenData, sponsorTokenData);

        validationData = _packValidationData(false, validUntil, validAfter);
        context = "";
    }

    /**
     * @dev Handles token operations including transfers and swaps if needed
     * @param repayTokenData Data about tokens to be repaid
     * @param sponsorTokenData Data about tokens to be sponsored
     */
    function _handleTokenOperations(bytes calldata repayTokenData, bytes calldata sponsorTokenData) internal {
        // Parse token data
        (uint8 repayTokenLength, address[] memory repayTokens, address[] memory repaySpenders, uint256[] memory repayAmounts) = 
            _parseTokenData(repayTokenData);
        (uint8 sponsorTokenLength, address[] memory sponsorTokens, address[] memory sponsorSpenders, uint256[] memory sponsorAmounts) = 
            _parseTokenData(sponsorTokenData);

        // Handle repay tokens
        for (uint8 i = 0; i < repayTokenLength;) {
            address token = repayTokens[i];
            address spender = repaySpenders[i];
            uint256 amount = repayAmounts[i];

            if (token != NATIVE_TOKEN) {
                uint256 paymasterBalance = IERC20(token).balanceOf(address(this));
                if (paymasterBalance < amount) {
                    // Source liquidity from MiniSwap if needed
                    uint256 amountNeeded = amount - paymasterBalance;
                    try liquidityManager.swapExactTokensForTokens(
                        token,
                        token,
                        amountNeeded,
                        amountNeeded * 95 / 100 // Allow 5% slippage
                    ) returns (uint256 amountReceived) {
                        require(amountReceived + paymasterBalance >= amount, "CABPaymaster: INSUFFICIENT_LIQUIDITY_AFTER_SWAP");
                    } catch {
                        revert("CABPaymaster: LIQUIDITY_SOURCING_FAILED");
                    }
                }
                IERC20(token).safeTransferFrom(spender, address(this), amount);
            }
            unchecked {
                ++i;
            }
        }

        // Handle sponsor tokens
        for (uint8 i = 0; i < sponsorTokenLength;) {
            address token = sponsorTokens[i];
            address spender = sponsorSpenders[i];
            uint256 amount = sponsorAmounts[i];

            if (token != NATIVE_TOKEN) {
                uint256 paymasterBalance = IERC20(token).balanceOf(address(this));
                if (paymasterBalance < amount) {
                    // Source liquidity from MiniSwap if needed
                    uint256 amountNeeded = amount - paymasterBalance;
                    try liquidityManager.swapExactTokensForTokens(
                        token,
                        token,
                        amountNeeded,
                        amountNeeded * 95 / 100 // Allow 5% slippage
                    ) returns (uint256 amountReceived) {
                        require(amountReceived + paymasterBalance >= amount, "CABPaymaster: INSUFFICIENT_LIQUIDITY_AFTER_SWAP");
                    } catch {
                        revert("CABPaymaster: LIQUIDITY_SOURCING_FAILED");
                    }
                }
                IERC20(token).safeTransferFrom(spender, address(this), amount);
            }
            unchecked {
                ++i;
            }
        }
    }

    function _parseTokenData(bytes calldata tokenData)
        internal
        pure
        returns (uint8 tokenLength, address[] memory tokens, address[] memory spenders, uint256[] memory amounts)
    {
        tokenLength = uint8(bytes1(tokenData[0]));

        // 1 byte: length
        // length * 72 bytes: (20 bytes: token adddress + 20 bytes: spender address + 32 bytes: amount)

        require(tokenData.length == 1 + tokenLength * 72, "CABPaymaster: invalid tokenData length");

        tokens = new address[](tokenLength);
        spenders = new address[](tokenLength);
        amounts = new uint256[](tokenLength);
        for (uint256 i = 0; i < uint256(tokenLength);) {
            uint256 offset = 1 + i * 72;
            address token = address(bytes20(tokenData[offset:offset + 20]));
            address spender = address(bytes20(tokenData[offset + 20:offset + 40]));
            uint256 amount = uint256(bytes32(tokenData[offset + 40:offset + 72]));

            tokens[i] = token;
            spenders[i] = spender;
            amounts[i] = amount;

            unchecked {
                i++;
            }
        }
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256 actualUserOpFeePerGas)
        internal
        virtual
        override
    {
        bytes calldata sponsorTokenData = context[84:];

        (uint8 sponsorTokenLength, SponsorToken[] memory sponsorTokens) = parseSponsorTokenData(sponsorTokenData);
        for (uint8 i = 0; i < sponsorTokenLength;) {
            address token = sponsorTokens[i].token;
            address spender = sponsorTokens[i].spender;
            if (token != NATIVE_TOKEN) {
                require(IERC20(token).approve(spender, 0), "Reset approval failed");
            }
            unchecked {
                i++;
            }
        }
        // TODO: Batch Proving Optimistation -> write in settlement contract on `opSucceeded`
        if (mode == PostOpMode.opSucceeded) {
            //emit IInvoiceManager.InvoiceCreated(bytes32(context[:32]), address(bytes20(context[32:52])), address(this));

            // This add ~= 100k gas compared to only emitting the InvoiceCreated event
            // Question: is storing the invoices onchain truly necessary?
            bytes32 invoiceId = bytes32(context[:32]);
            address account = address(bytes20(context[32:52]));
            uint256 nonce = uint256(bytes32(context[52:84]));
            invoiceManager.createInvoice(nonce, account, invoiceId);
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
        returns (uint8 sponsorTokenLength, SponsorToken[] memory sponsorTokens)
    {
        sponsorTokenLength = uint8(bytes1(sponsorTokenData[0]));

        // 1 byte: length
        // length * 72 bytes: (20 bytes: token adddress + 20 bytes: spender address + 32 bytes: amount)
        require(sponsorTokenData.length == 1 + sponsorTokenLength * 72, "CABPaymaster: invalid sponsorTokenData length");

        sponsorTokens = new SponsorToken[](sponsorTokenLength);
        for (uint256 i = 0; i < uint256(sponsorTokenLength);) {
            uint256 offset = 1 + i * 72;
            address token = address(bytes20(sponsorTokenData[offset:offset + 20]));
            address spender = address(bytes20(sponsorTokenData[offset + 20:offset + 40]));
            uint256 amount = uint256(bytes32(sponsorTokenData[offset + 40:offset + 72]));

            sponsorTokens[i] = SponsorToken(token, spender, amount);

            unchecked {
                i++;
            }
        }
    }

    function _encodeRepayToken(IInvoiceManager.RepayTokenInfo[] memory repayTokens)
        internal
        pure
        returns (bytes memory encodedRepayToken)
    {
        for (uint8 i = 0; i < repayTokens.length; i++) {
            encodedRepayToken = bytes.concat(
                encodedRepayToken,
                bytes20(address(repayTokens[i].vault)),
                bytes32(repayTokens[i].amount),
                bytes32(repayTokens[i].chainId)
            );
        }
        return abi.encodePacked(uint8(repayTokens.length), encodedRepayToken);
    }
}

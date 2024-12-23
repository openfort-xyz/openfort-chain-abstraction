// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVault} from "./IVault.sol";
import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";

/**
 * @title Interface for the InvoiceManager contract.
 */
interface IInvoiceManager {
    /**
     * @notice Emitted when a paymaster is registered.
     * @param account The account that registered the paymaster.
     * @param paymaster The address of the paymaster.
     * @param paymasterVerifier The address of the paymaster verifier.
     * @param expiry The expiry time of the paymaster.
     */
    event PaymasterRegistered(
        address indexed account, address indexed paymaster, IPaymasterVerifier indexed paymasterVerifier, uint256 expiry
    );

    /**
     * @notice Emitted when a paymaster is revoked.
     * @param account The account that revoked the paymaster.
     * @param paymaster The address of the paymaster.
     * @param paymasterVerifier The address of the paymaster verifier.
     */
    event PaymasterRevoked(
        address indexed account, address indexed paymaster, IPaymasterVerifier indexed paymasterVerifier
    );

    /**
     * @notice Emitted when an invoice is created.
     * @param invoiceId The ID of the invoice.
     * @param account The account that created the invoice.
     * @param paymaster The address of the paymaster.
     */
    event InvoiceCreated(bytes32 indexed invoiceId, address indexed account, address indexed paymaster);

    /**
     * @notice Emitted when an invoice is repaid.
     * @param invoiceId The ID of the invoice.
     * @param account The account that repaid the invoice.
     * @param paymaster The address of the paymaster.
     */
    event InvoiceRepaid(bytes32 indexed invoiceId, address indexed account, address indexed paymaster);

    /// @notice Struct to represent the CAB paymaster.
    struct CABPaymaster {
        address paymaster;
        IPaymasterVerifier paymasterVerifier;
        uint256 expiry;
    }

    struct RepayTokenInfo {
        IVault vault;
        uint256 amount;
        uint256 chainId;
    }

    /// @notice Struct to represent the invoice.
    struct Invoice {
        address account;
        uint256 nonce;
        address paymaster;
        uint256 sponsorChainId;
    }

    /// @notice Struct to represent the invoice.
    struct InvoiceWithRepayTokens {
        address account;
        uint256 nonce;
        address paymaster;
        uint256 sponsorChainId;
        RepayTokenInfo[] repayTokenInfos;
    }

    /**
     * @notice Register the CAB paymaster for the smart account.
     * @param paymaster The address of the paymaster.
     * @param paymasterVerifier The address of the paymaster verifier.
     * @param expiry The expiry time of the paymaster.
     */
    function registerPaymaster(address paymaster, IPaymasterVerifier paymasterVerifier, uint256 expiry) external;

    /**
     * @notice Revoke the CAB paymaster.
     */
    function revokePaymaster() external;

    /**
     * @notice Create a new invoice.
     * @dev The invoideId is generated using the sender, nonce, chainId and repayChainId.
     * @param nonce The nonce of the invoice.
     * @param paymaster The address of the paymaster.
     * @param invoiceId The ID of the invoice.
     */
    function createInvoice(uint256 nonce, address paymaster, bytes32 invoiceId) external;

    /**
     * @notice Repay the invoice.
     * @param invoiceId The ID of the invoice.
     * @param invoice The invoice to repay.
     * @param proof The proof of the repayment.
     */
    function repay(bytes32 invoiceId, InvoiceWithRepayTokens calldata invoice, bytes calldata proof) external;

    /**
     * @notice Withdraw the locked tokens to the account.
     * @param account The address of the account.
     * @param repayTokenVaults The vault of the tokens to repay.
     * @param repayAmounts The amounts to repay.
     */
    function withdrawToAccount(address account, IVault[] calldata repayTokenVaults, uint256[] calldata repayAmounts)
        external;

    /**
     * @notice Get the CAB paymaster.
     * @param account The address of the account.
     * @return cabPaymaster The CAB paymaster.
     */
    function getCABPaymaster(address account) external view returns (CABPaymaster memory);

    /**
     * @notice Get the invoice.
     * @param invoiceId The ID of the invoice.
     * @return invoice The invoice.
     */
    function getInvoice(bytes32 invoiceId) external view returns (Invoice memory);

    /**
     * @notice Get the invoice ID.
     * @param account The address of the account.
     * @param paymaster The address of the paymaster.
     * @param nonce The nonce of the invoice.
     * @param sponsorChainId The chain ID of the sponsor.
     * @param repayTokenInfos The tokens to repay.
     * @return invoiceId The ID of the invoice.
     */
    function getInvoiceId(
        address account,
        address paymaster,
        uint256 nonce,
        uint256 sponsorChainId,
        RepayTokenInfo[] calldata repayTokenInfos
    ) external view returns (bytes32);
}

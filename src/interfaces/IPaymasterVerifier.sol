// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVault} from "./IVault.sol";
import {IInvoiceManager} from "./IInvoiceManager.sol";

/**
 * @title Interface for the PaymasterVerifier contract.
 */
interface IPaymasterVerifier {
    /// @notice Emitted when an invoice is created.
    event InvoiceCreated(bytes32 indexed invoiceId);

    /// @notice The struct of the sponsor token.
    struct SponsorToken {
        address token;
        address spender;
        uint256 amount;
    }

    /**
     * @notice Verify the invoice.
     * @param invoiceId The ID of the invoice.
     * @param invoice The invoice to verify.
     * @param proof The proof of the invoice.
     */
    function verifyInvoice(
        bytes32 invoiceId,
        IInvoiceManager.InvoiceWithRepayTokens calldata invoice,
        bytes calldata proof
    ) external returns (bool);

    /**
     * @notice Withdraw the token.
     */
    function withdraw(address token, uint256 amount) external;
}

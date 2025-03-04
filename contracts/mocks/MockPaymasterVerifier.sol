// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";
import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";

contract MockPaymasterVerifier is IPaymasterVerifier {
    bool private shouldVerify;

    constructor(bool _shouldVerify) {
        shouldVerify = _shouldVerify;
    }

    function verifyInvoice(bytes32 invoiceId, IInvoiceManager.InvoiceWithRepayTokens calldata invoice, bytes calldata proof)
        external
        view
        returns (bool)
    {
        return shouldVerify;
    }
}

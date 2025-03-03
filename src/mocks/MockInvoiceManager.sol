// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";
import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";
import {IVault} from "../interfaces/IVault.sol";

interface IMockInvoiceManager is IInvoiceManager {
    function setInvoiceId(bytes32 _invoiceId) external;
}

contract MockInvoiceManager is IMockInvoiceManager {
    bytes32 public invoiceId;

    function setInvoiceId(bytes32 _invoiceId) external {
        invoiceId = _invoiceId;
    }

    function getInvoiceId(address, address, uint256, uint256, bytes calldata) external view returns (bytes32) {
        return invoiceId;
    }

    function getCABPaymaster(address) external view returns (CABPaymaster memory) {
        revert("Not implemented");
    }

    function registerPaymaster(address, IPaymasterVerifier, uint256) external {
        revert("Not implemented");
    }

    function revokePaymaster() external {
        revert("Not implemented");
    }

    function createInvoice(uint256, address, bytes32) external {
        revert("Not implemented");
    }

    function repay(bytes32, InvoiceWithRepayTokens calldata, bytes calldata) external {
        revert("Not implemented");
    }

    function withdrawToAccount(address, IVault[] calldata, uint256[] calldata) external {
        revert("Not implemented");
    }

    function getInvoice(bytes32) external view returns (Invoice memory) {
        revert("Not implemented");
    }
}

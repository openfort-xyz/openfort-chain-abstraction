// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";
import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";
import {IVault} from "../interfaces/IVault.sol";

contract MockInvoiceManager is IInvoiceManager {
    function getInvoiceId(address, address, uint256, uint256, bytes calldata) external view returns (bytes32) {
        return 0x6f662367c1c8c75c2bd3494c5b0338a59cd67fe855e0c298cd875420ccf403ff;
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

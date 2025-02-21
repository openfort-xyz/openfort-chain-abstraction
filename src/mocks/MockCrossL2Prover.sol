// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";
import {LightClientType} from "@vibc-core-smart-contracts/contracts/interfaces/ILightClient.sol";

contract MockCrossL2Prover is ICrossL2Prover {
    address public invoiceManager;

    // Since the InvoiceManager emits the InoiceCreated event
    // real crossL2Prover.valiadateEvent will return its address
    constructor(address _invoiceManager) {
        invoiceManager = _invoiceManager;
    }

    function validateEvent(uint256, bytes calldata /* eventData */)
        external
        view
        returns (string memory chainId, address emittingContract, bytes[] memory topics, bytes memory unindexedData)
    {
        // Decode the provided eventData
        (chainId, emittingContract, topics, unindexedData) = abi.decode(constructEventData(), (string, address, bytes[], bytes));
    }

    function validateReceipt(bytes calldata) external pure returns (string memory, bytes calldata) {
        revert("not implemented");
    }

    function getState(uint256) external pure returns (uint256) {
        revert("not implemented");
    }

    function LIGHT_CLIENT_TYPE() external pure returns (LightClientType) {
        revert("not implemented");
    }

    function updateClient(bytes calldata, uint256, uint256) external pure {
        revert("not implemented");
    }

    // Helper function to construct the data dynamically (for testing or flexibility)
    function constructEventData() public view returns (bytes memory) {
        bytes[] memory topics = new bytes[](2);
        topics[0] = hex"5243d6c5479d93025de9e138a29c467868f762bb78591e96299fb3f437afcc04";
        topics[1] = hex"28a285ad4af66f8b864972de6e0ea1095667e73ade7db3d93151c0c266022905";
        return abi.encode(
            "84532", // chainId
            invoiceManager, // emittingContract
            topics,
            bytes("") // unindexedData
        );
    }
}
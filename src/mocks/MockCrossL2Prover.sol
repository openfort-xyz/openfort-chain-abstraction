// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";
import {LightClientType} from "@vibc-core-smart-contracts/contracts/interfaces/ILightClient.sol";

contract MockCrossL2Prover is ICrossL2Prover {
    function validateEvent(uint256 logIndex, bytes calldata proof)
        external
        pure
        returns (string memory chainId, address emittingContract, bytes[] memory topics, bytes memory unindexedData)
    {
        (chainId, emittingContract, topics, unindexedData) = abi.decode(
            hex"00000000000000000000000000000000000000000000000000000000000000800000000000000000000000003cb057fd3be519cb50788b8b282732edbf533dc600000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000005383435333200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000205243d6c5479d93025de9e138a29c467868f762bb78591e96299fb3f437afcc04000000000000000000000000000000000000000000000000000000000000002028a285ad4af66f8b864972de6e0ea1095667e73ade7db3d93151c0c2660229050000000000000000000000000000000000000000000000000000000000000000",
            (string, address, bytes[], bytes)
        );
    }

    function validateReceipt(bytes calldata) external pure returns (string memory srcChainId, bytes calldata receiptRLP) {
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
}

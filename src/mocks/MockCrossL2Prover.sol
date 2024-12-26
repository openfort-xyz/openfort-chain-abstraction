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
            hex"00000000000000000000000000000000000000000000000000000000000000800000000000000000000000003cb057fd3be519cb50788b8b282732edbf533dc600000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000538343533320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000020ab6994bba319b437692f1dbbe4d689382f25c4cfa9a291959e0af1ca5cd9e13f0000000000000000000000000000000000000000000000000000000000000020886f7a98cfb9c6f2b6a6b4be00a89b75c0a846bf1c9b265b17ba4f9452acbc640000000000000000000000000000000000000000000000000000000000000000",
            (string, address, bytes[], bytes)
        );
    }

    function validateReceipt(bytes calldata proof)
        external
        view
        returns (string memory srcChainId, bytes calldata receiptRLP)
    {
        revert("not implemented");
    }

    function getState(uint256 height) external view returns (uint256) {
        revert("not implemented");
    }

    function LIGHT_CLIENT_TYPE() external view returns (LightClientType) {
        revert("not implemented");
    }

    function updateClient(bytes calldata proof, uint256 height, uint256 appHash) external {
        revert("not implemented");
    }
}

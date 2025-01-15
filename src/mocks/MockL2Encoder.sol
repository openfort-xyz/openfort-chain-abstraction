// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from "aave-v3-origin/core/contracts/interfaces/IPool.sol";

/**
 * @title MockL2Encoder
 * @dev A mock implementation of the L2Encoder for testing purposes.
 */
contract MockL2Encoder {
    IPool public pool;

    /**
     * @notice Constructor to initialize the mock with a reference to the Aave Pool.
     * @param _pool Address of the Aave Pool.
     */
    constructor(address _pool) {
        pool = IPool(_pool);
    }

    /**
     * @notice Encodes the parameters for a supply operation.
     * @param asset The address of the asset being supplied.
     * @param amount The amount of the asset being supplied.
     * @param referralCode The referral code for the supply operation.
     * @return Encoded parameters as bytes32.
     */
    function encodeSupplyParams(address asset, uint256 amount, uint16 referralCode) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(asset, amount, referralCode));
    }

    /**
     * @notice Encodes the parameters for a withdrawal operation.
     * @param asset The address of the asset being withdrawn.
     * @param amount The amount of the asset being withdrawn.
     * @return Encoded parameters as bytes32.
     */
    function encodeWithdrawParams(address asset, uint256 amount) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(asset, amount));
    }
}

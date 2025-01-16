// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./MockERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CalldataLogic} from "aave-v3-origin/core/contracts/protocol/libraries/logic/CalldataLogic.sol";

/**
 * @title MockL2AavePool
 * @notice A simplified mock for Aave L2 Pool to test interactions with AaveVault on L2.
 */
contract MockL2AavePool {
    using SafeERC20 for IERC20;

    struct Reserve {
        uint256 totalLiquidity;
        address aTokenAddress;
        address asset;
    }

    Reserve public reserve;

    function addReserve(address underlyingToken, address aToken) external {
        reserve = Reserve({totalLiquidity: 0, aTokenAddress: aToken, asset: underlyingToken});
    }

    function supply(bytes32 args) external {
        // Simulate supply logic. Simulate amount just for testing purposes
        IERC20(reserve.asset).safeTransferFrom(msg.sender, address(this), 100 ether); // Transfer underlying to pool
        IERC20(reserve.aTokenAddress).safeTransfer(msg.sender, 100 ether); // Mint aTokens to user

        reserve.totalLiquidity += 100 ether;
    }

    function withdraw(bytes32 args) external {
        // Simulate withdraw logic. Simulate amount just for testing purposes
        IERC20(reserve.asset).safeTransfer(msg.sender, 100 ether); // Transfer underlying to user

        reserve.totalLiquidity -= 100 ether;
    }

    function getTotalLiquidity() external view returns (uint256) {
        return reserve.totalLiquidity;
    }
}

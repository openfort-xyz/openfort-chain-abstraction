// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./MockERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockAavePool
 * @notice A simplified mock for Aave Pool to test interactions with AaveVault.
 */
contract MockAavePool {
    using SafeERC20 for IERC20;

    struct Reserve {
        uint256 totalLiquidity; // Total liquidity in the pool
        address aTokenAddress; // Address of the associated aToken
    }

    mapping(address => Reserve) public reserves;

    event Supply(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event YieldGenerated(address indexed user, address indexed asset, uint256 amount);

    /**
     * @notice Adds support for a new token and links it with an aToken.
     * @param underlyingToken Address of the underlying token.
     * @param aToken Address of the associated aToken.
     */
    function addReserve(address underlyingToken, address aToken) external {
        require(reserves[underlyingToken].aTokenAddress == address(0), "MockAavePool: Reserve already exists");
        reserves[underlyingToken] = Reserve({totalLiquidity: 0, aTokenAddress: aToken});
    }

    /**
     * @notice Supplies liquidity to the pool and mints aTokens.
     * @param asset Address of the token to deposit.
     * @param amount Amount of tokens to deposit.
     * @param onBehalfOf Address to mint aTokens for.
     * @dev referralCode Referral code (ignored in mock implementation).
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        Reserve storage reserve = reserves[asset];
        require(reserve.aTokenAddress != address(0), "MockAavePool: Unsupported asset");

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(reserve.aTokenAddress).safeTransfer(onBehalfOf, amount); // Mint aTokens 1:1

        reserve.totalLiquidity += amount;

        emit Supply(onBehalfOf, asset, amount);
    }

    /**
     * @notice Withdraws liquidity from the pool and burns aTokens.
     * @param asset Address of the token to withdraw.
     * @param amount Amount of tokens to withdraw.
     * @param to Address to send the withdrawn tokens to.
     */
    function withdraw(address asset, uint256 amount, address to) external {
        Reserve storage reserve = reserves[asset];
        require(reserve.aTokenAddress != address(0), "MockAavePool: Unsupported asset");

        IERC20(asset).safeTransfer(to, amount);

        reserve.totalLiquidity -= amount;

        emit Withdraw(msg.sender, asset, amount);
    }

    /**
     * @notice Generates yield by minting additional aTokens for a user.
     * @param asset Address of the underlying token.
     * @param amount Amount of yield to generate.
     * @param user Address of the user to mint aTokens for.
     */
    function generateYield(address asset, uint256 amount, address user) external {
        Reserve storage reserve = reserves[asset];
        require(reserve.aTokenAddress != address(0), "MockAavePool: Unsupported asset");

        IERC20(reserve.aTokenAddress).safeTransfer(user, amount); // Mint yield as aTokens

        emit YieldGenerated(user, asset, amount);
    }
}

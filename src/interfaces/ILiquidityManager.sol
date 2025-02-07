// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

interface ILiquidityManager {
    /**
     * @dev Attempts to swap tokens using the best available path
     * @param tokenIn The token to swap from
     * @param tokenOut The token to swap to
     * @param amountIn The amount of tokenIn to swap
     * @param minAmountOut The minimum amount of tokenOut to receive
     * @return amountOut The amount of tokenOut received
     */
    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut);

    /**
     * @dev Gets the expected output amount for a swap
     * @param tokenIn The input token
     * @param tokenOut The output token
     * @param amountIn The input amount
     * @return amountOut The expected output amount
     */
    function getExpectedOutputAmount(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut);
}

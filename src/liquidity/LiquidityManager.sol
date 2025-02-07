// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../exchange/MiniSwap/MiniRouter.sol";
import "../exchange/MiniSwap/MiniFactory.sol";

/**
 * @title LiquidityManager
 * @dev Manages external liquidity sourcing for CABPaymaster through MiniSwap
 */
contract LiquidityManager is Ownable {
    using SafeERC20 for IERC20;

    MiniRouter public immutable router;
    MiniFactory public immutable factory;

    // Minimum amount of tokens that should be received after a swap
    uint256 public constant MIN_SWAP_AMOUNT_OUT = 1;
    
    // Maximum slippage allowed (in basis points, 1/10000)
    uint256 public slippageTolerance = 50; // 0.5%

    event SwapExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address _router, address _factory) Ownable(msg.sender){
        router = MiniRouter(_router);
        factory = MiniFactory(_factory);
    }

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
    ) external returns (uint256 amountOut) {
        require(amountIn > 0, "LiquidityManager: INVALID_INPUT_AMOUNT");
        
        // Create the path for the swap
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // Approve router to spend tokens
        IERC20(tokenIn).approve(address(router), amountIn);

        // Execute the swap
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            msg.sender,
            block.timestamp
        );

        amountOut = amounts[amounts.length - 1];
        require(amountOut >= minAmountOut, "LiquidityManager: INSUFFICIENT_OUTPUT_AMOUNT");

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);
        return amountOut;
    }

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
    ) external view returns (uint256 amountOut) {
        address pair = factory.getPair(tokenIn, tokenOut);
        require(pair != address(0), "LiquidityManager: PAIR_NOT_FOUND");

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = router.getAmountsOut(amountIn, path);
        return amounts[1];
    }

    /**
     * @dev Sets the slippage tolerance for swaps
     * @param _slippageTolerance New slippage tolerance in basis points (1/10000)
     */
    function setSlippageTolerance(uint256 _slippageTolerance) external onlyOwner {
        require(_slippageTolerance <= 1000, "LiquidityManager: SLIPPAGE_TOO_HIGH"); // Max 10%
        slippageTolerance = _slippageTolerance;
    }

    /**
     * @dev Approves tokens for the router to spend
     * @param tokens Array of token addresses to approve
     */
    function approveTokens(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(router), type(uint256).max);
        }
    }

    /**
     * @dev Revokes token approvals from the router
     * @param tokens Array of token addresses to revoke approval from
     */
    function revokeTokenApprovals(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(router), 0);
        }
    }
}

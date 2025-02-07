// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MiniFactory.sol";
import "./MiniPair.sol";

contract MiniRouter {
    using SafeERC20 for IERC20;

    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(deadline >= block.timestamp, "MiniRouter: EXPIRED");

        // Get pair address
        address pair = MiniFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "MiniRouter: PAIR_NOT_FOUND");

        (amountA, amountB) = _calculateLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        // Transfer tokens to this contract first
        IERC20(tokenA).transferFrom(msg.sender, address(pair), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(pair), amountB);

        // Add liquidity to pair
        MiniPair(pair).addLiquidity(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(deadline >= block.timestamp, "MiniRouter: EXPIRED");

        address pair = MiniFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "MiniRouter: PAIR_NOT_FOUND");

        // Remove liquidity directly from the sender
        (amountA, amountB) = MiniPair(pair).removeLiquidity(liquidity, to);

        require(amountA >= amountAMin, "MiniRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "MiniRouter: INSUFFICIENT_B_AMOUNT");
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, "MiniRouter: EXPIRED");
        require(path.length >= 2, "MiniRouter: INVALID_PATH");

        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "MiniRouter: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(path[0]).safeTransferFrom(msg.sender, MiniFactory(factory).getPair(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function _calculateLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        address pair = MiniFactory(factory).getPair(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1) = _getReserves(pair);

        if (reserve0 == 0 && reserve1 == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserve0, reserve1);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "MiniRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(amountBDesired, reserve1, reserve0);
                require(amountAOptimal <= amountADesired, "MiniRouter: EXCESSIVE_INPUT_AMOUNT");
                require(amountAOptimal >= amountAMin, "MiniRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal {
        for (uint256 i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = _sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];

            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));

            // For intermediary swaps, the recipient is the next pair
            address recipient = i < path.length - 2 ? MiniFactory(factory).getPair(path[i + 1], path[i + 2]) : _to;

            MiniPair(MiniFactory(factory).getPair(input, output)).swap(amount0Out, amount1Out, recipient);
        }
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _getReserves(address pair) internal view returns (uint256 reserve0, uint256 reserve1) {
        if (pair == address(0)) return (0, 0);
        reserve0 = MiniPair(pair).reserve0();
        reserve1 = MiniPair(pair).reserve1();
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, "MiniRouter: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "MiniRouter: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "MiniRouter: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < path.length - 1; i++) {
            (uint256 reserve0, uint256 reserve1) = _getReserves(MiniFactory(factory).getPair(path[i], path[i + 1]));
            amounts[i + 1] = getAmountOut(amounts[i], reserve0, reserve1);
        }
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "MiniRouter: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "MiniRouter: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}

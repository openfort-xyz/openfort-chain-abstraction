// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MiniPair is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint256 public immutable fee; // Fee in basis points (1/10000)

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 private unlocked = 1;

    constructor(address _token0, address _token1, uint256 _fee) ERC20("Mini LP Token", "MINI-LP") {
        factory = msg.sender;
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
    }

    modifier lock() {
        require(unlocked == 1, "MiniPair: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function addLiquidity(address to)
        external
        nonReentrant
        returns (uint256 liquidity)
    {
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        require(amount0 > 0 && amount1 > 0, "MiniPair: INSUFFICIENT_INPUT_AMOUNT");

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = sqrt(amount0 * amount1);
            _mint(to, liquidity);
        } else {
            uint256 _liquidity0 = amount0 * _totalSupply / _reserve0;
            uint256 _liquidity1 = amount1 * _totalSupply / _reserve1;
            liquidity = _liquidity0 < _liquidity1 ? _liquidity0 : _liquidity1;
            require(liquidity > 0, "MiniPair: INSUFFICIENT_LIQUIDITY_MINTED");
            _mint(to, liquidity);
        }
        _update();
    }

    function removeLiquidity(uint256 liquidity, address to)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        // Calculate token amounts based on liquidity proportion
        uint256 _totalSupply = totalSupply();
        amount0 = (liquidity * reserve0) / _totalSupply;
        amount1 = (liquidity * reserve1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "MiniPair: INSUFFICIENT_LIQUIDITY_BURNED");

        // Burn LP tokens and transfer underlying tokens
        _burn(to, liquidity);
        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        // Update reserves
        _update();
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external lock nonReentrant {
        require(amount0Out > 0 || amount1Out > 0, "MiniPair: INSUFFICIENT_OUTPUT_AMOUNT");
        require(amount0Out < reserve0 && amount1Out < reserve1, "MiniPair: INSUFFICIENT_LIQUIDITY");

        uint256 balance0Before = reserve0;
        uint256 balance1Before = reserve1;

        if (amount0Out > 0) IERC20(token0).safeTransfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).safeTransfer(to, amount1Out);

        uint256 balance0After = IERC20(token0).balanceOf(address(this));
        uint256 balance1After = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0After - (balance0Before - amount0Out);
        uint256 amount1In = balance1After - (balance1Before - amount1Out);

        require(amount0In > 0 || amount1In > 0, "MiniPair: INSUFFICIENT_INPUT_AMOUNT");

        {
            uint256 balance0Adjusted = (balance0After * 10000) - (amount0In * fee);
            uint256 balance1Adjusted = (balance1After * 10000) - (amount1In * fee);
            require(balance0Adjusted * balance1Adjusted >= reserve0 * reserve1 * (10000 ** 2), "MiniPair: K");
        }

        _update();
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, "MiniPair: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "MiniPair: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    function _update() private {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        reserve0 = balance0;
        reserve1 = balance1;
    }

    // Helper functions
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {IVault} from "../interfaces/IVault.sol";
import {BaseVault} from "./BaseVault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IPool} from "aave-v3-origin/core/contracts/interfaces/IPool.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveVault is BaseVault {
    using SafeERC20 for IERC20;

    IPool public aavePool;
    IERC20 public aToken;

    function initialize(
        IVaultManager _vaultManager,
        IERC20 _underlyingToken, // The actual token (e.g., DAI)
        IERC20 _aToken, // The aToken (e.g., aDAI)
        IPool _aavePool
    ) public initializer {
        require(address(_aavePool) != address(0), "AaveVault: invalid Aave Pool address");
        require(address(_underlyingToken) != address(0), "AaveVault: invalid underlying token address");
        require(address(_aToken) != address(0), "AaveVault: invalid aToken address");

        aToken = _aToken;
        aavePool = _aavePool;

        super.initialize(_vaultManager, _underlyingToken);
    }

    function _afterDeposit(IERC20 token, uint256 amount, bool isYield) internal override {
        underlyingToken.approve(address(aavePool), amount);

        (bool success,) = address(aavePool).call(
            abi.encodeWithSelector(IPool.supply.selector, address(underlyingToken), amount, address(this), 0)
        );
        require(success, "AaveVault: Supply to Aave failed");
    }

    function _afterWithdraw(IERC20 token, uint256 amount, address recipient) internal override {
        (bool success,) =
            address(aavePool).call(abi.encodeWithSelector(IPool.withdraw.selector, token, amount, recipient));

        require(success, "AaveVault: Withdraw from Aave failed");
    }

    function _totalAssets() internal view virtual override returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    function _previewDeposit(uint256 priorTotalShares, IERC20 token, uint256 amount, bool isYield)
        internal
        view
        override
        returns (uint256)
    {
        uint256 virtualShareAmount = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = totalAssets() + BALANCE_OFFSET;

        uint256 virtualPriorTokenBalance = virtualTokenBalance;
        uint256 newShares = (amount * virtualShareAmount) / virtualPriorTokenBalance;

        return newShares;
    }
}

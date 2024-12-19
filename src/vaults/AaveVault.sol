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
    // Aave necessary libraries

    IPool public aavePool;

    IERC20 public aToken; // The aToken corresponding to the underlying token

    function initialize(
        IVaultManager _vaultManager,
        IERC20 _underlyingToken, // The actual token (e.g., DAI)
        IERC20 _aToken, // The aToken (e.g., aDAI)
        IPool _aavePool
    ) public initializer {
        require(address(_aavePool) != address(0), "AaveVault: invalid Aave Pool address");
        require(address(_underlyingToken) != address(0), "AaveVault: invalid underlying token address");
        require(address(_aToken) != address(0), "AaveVault: invalid aToken address");

        // Assign the aToken
        aToken = _aToken;

        // Assign the Aave Pool
        aavePool = _aavePool;

        // Initialize the BaseVault
        super.initialize(_vaultManager, _underlyingToken);
    }

    function _afterDeposit(IERC20 token, uint256 amount, bool isYield) internal override {
        // Approve the Aave Pool to spend the underlying tokens
        underlyingToken.approve(address(aavePool), amount);

        // Perform a low-level call to the `supply` function of the Aave Pool
        (bool success,) = address(aavePool).call(
            abi.encodeWithSelector(
                IPool.supply.selector,
                address(underlyingToken), // Underlying token
                amount, // Amount to supply
                address(this), // On-behalf-of address
                0 // Referral code
            )
        );
        require(success, "AaveVault: Supply to Aave failed");
    }

    function _afterWithdraw(IERC20 token, uint256 amount, address recipient) internal override {
        // Perform a low-level call to the `withdraw` function of the Aave Pool
        (bool success,) =
            address(aavePool).call(abi.encodeWithSelector(IPool.withdraw.selector, token, amount, recipient));

        // Revert the transaction if the call fails
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

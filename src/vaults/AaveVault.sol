// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {IVault} from "../interfaces/IVault.sol";
import {BaseVault} from "./BaseVault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IPool} from "aave-v3-origin/core/contracts/interfaces/IPool.sol";
// import {L2Encoder} from "aave-v3-origin/core/contracts/misc/L2Encoder.sol";
import {AaveProtocolDataProvider} from "aave-v3-origin/core/contracts/misc/AaveProtocolDataProvider.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract AaveVault is BaseVault {
    using SafeERC20 for IERC20;
    // Aave necessary libraries
    IPool public aavePool;
    // L2Encoder public l2Encoder;
    AaveProtocolDataProvider public dataProvider;

    IERC20 public aToken; // The aToken corresponding to the underlying token

    function initialize(
        IVaultManager _vaultManager,
        IERC20 _underlyingToken, // The actual token (e.g., DAI)
        IERC20 _aToken, // The aToken (e.g., aDAI)
        IPool _aavePool
    )
        public
        // L2Encoder _l2Encoder // , AaveProtocolDataProvider _dataProvider
        initializer
    {
        require(
            address(_aavePool) != address(0),
            "AaveVault: invalid Aave Pool address"
        );
        require(
            address(_underlyingToken) != address(0),
            "AaveVault: invalid underlying token address"
        );
        require(
            address(_aToken) != address(0),
            "AaveVault: invalid aToken address"
        );

        // Assign the aToken
        aToken = _aToken;

        // Assign the Aave Pool
        aavePool = _aavePool;

        // Initialize the BaseVault
        super.initialize(_vaultManager, _underlyingToken);
    }

    function _beforeDeposit(
        IERC20 token,
        uint256 amount,
        bool isYield
    ) internal override {
        // Log the initial balance of the underlying token in the vault
        uint256 initialVaultBalance = token.balanceOf(address(this));
        console.log(
            "Vault Initial Underlying Token Balance:",
            initialVaultBalance
        );

        // Approve the Aave Pool to spend the underlying tokens
        underlyingToken.approve(address(aavePool), amount);

        // Log the allowance from the vault to the Aave Pool after approval
        uint256 allowanceToPool = underlyingToken.allowance(
            address(this),
            address(aavePool)
        );
        console.log(
            "Allowance from Vault to Aave Pool after approve:",
            allowanceToPool
        );

        // Perform a low-level call to the `supply` function of the Aave Pool
        (bool success, ) = address(aavePool).call(
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

    function _afterWithdraw(
        IERC20 token,
        uint256 amount,
        address recipient
    ) internal override {
        // bytes32 args = l2Encoder.encodeWithdrawParams(address(token), amount);

        // Perform a low-level call to the `withdraw` function of the Aave Pool
        (bool success, ) = address(aavePool).call(
            abi.encodeWithSelector(
                IPool.withdraw.selector,
                token,
                amount,
                recipient
            )
        );

        // Revert the transaction if the call fails
        require(success, "AaveVault: Withdraw from Aave failed");

        // uint256 withdrawnAmount = abi.decode(returnData, (uint256));

        // token.safeTransfer(recipient, withdrawnAmount);
    }

    function _totalAssets() internal view virtual override returns (uint256) {
        return aToken.balanceOf(address(this));
    }
}

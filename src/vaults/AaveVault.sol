// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IYieldVault} from "../interfaces/IYieldVault.sol";
import {IVault} from "../interfaces/IVault.sol";
import {BaseVault} from "./BaseVault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IL2Pool} from "aave-v3-origin/core/contracts/interfaces/IL2Pool.sol";
import {L2Encoder} from "aave-v3-origin/core/contracts/misc/L2Encoder.sol";
import {AaveProtocolDataProvider} from "aave-v3-origin/core/contracts/misc/AaveProtocolDataProvider.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract AaveVault is BaseVault, IYieldVault {
    using SafeERC20 for IERC20;
    // Aave necessary libraries
    IL2Pool public aavePool;
    L2Encoder public l2Encoder;
    AaveProtocolDataProvider public dataProvider;
    /// @notice The total amount of shares.
    uint256 public totalYieldShares;

    function initialize(
        IVaultManager _vaultManager,
        IERC20 _underlyingToken, // The token managed by this vault -- the aToken minted in a 1:1 ratio by Aave protocol
        IL2Pool _aavePool,
        L2Encoder _l2Encoder // , AaveProtocolDataProvider _dataProvider
    ) public initializer {
        require(
            address(_aavePool) != address(0),
            "AaveVault: invalid Aave Pool address"
        );
        require(
            address(_underlyingToken) != address(0),
            "AaveVault: invalid underlying token address"
        );

        aavePool = _aavePool;
        l2Encoder = _l2Encoder;
        // dataProvider = _dataProvider;
        // Initialize BaseVault
        super.initialize(_vaultManager, _underlyingToken);
    }

    function depositToYield(
        IERC20 token,
        uint256 amount,
        bool isYield
    ) external override onlyVaultManager returns (uint256 newShares) {
        //     _beforeDeposit(token, amount, isYield);
        //     uint256 priorTotalShares = totalShares;
        //     newShares = _previewDeposit(priorTotalShares, token, amount, isYield);
        //     require(newShares != 0, "Vault: newShare cannot be zero");
        //     totalShares = priorTotalShares + newShares;
        // underlyingToken.approve(address(aavePool), amount);
        // bytes32 args = l2Encoder.encodeSupplyParams(
        //     address(underlyingToken),
        //     amount,
        //     0
        // );
        // aavePool.supply(args);
        //     return newShares;
    }

    function _afterDeposit(
        IERC20 token,
        uint256 amount,
        bool isYield
    ) internal override {
        underlyingToken.approve(address(aavePool), amount);

        bytes32 args = l2Encoder.encodeSupplyParams(
            address(underlyingToken),
            amount,
            0
        );

        // Perform a low-level call to the `supply` function of the Aave Pool
        (bool success, ) = address(aavePool).call(
            abi.encodeWithSelector(IL2Pool.supply.selector, args)
        );
        require(success, "AaveVault: Supply to Aave failed");
    }

    function _afterWithdraw(
        IERC20 token,
        uint256 amount,
        address recipient
    ) internal override {
        bytes32 args = l2Encoder.encodeWithdrawParams(address(token), amount);

        // Perform a low-level call to the `withdraw` function of the Aave Pool
        (bool success, bytes memory returnData) = address(aavePool).call(
            abi.encodeWithSelector(IL2Pool.withdraw.selector, args)
        );

        // Revert the transaction if the call fails
        require(success, "AaveVault: Withdraw from Aave failed");

        uint256 withdrawnAmount = abi.decode(returnData, (uint256));

        token.safeTransfer(recipient, withdrawnAmount);
    }
}

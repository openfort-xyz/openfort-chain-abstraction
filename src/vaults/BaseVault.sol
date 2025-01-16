// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVault} from "../interfaces/IVault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Implementation of the IVault interface.
 */
contract BaseVault is UUPSUpgradeable, OwnableUpgradeable, IVault {
    using SafeERC20 for IERC20;

    /**
     * @notice Virtual shares mitigate 'share inflation' attacks.
     * The constant value balances between reducing initial depositor inflation and minimizing depositor losses.
     */
    uint256 internal constant SHARES_OFFSET = 1e3;

    /**
     * @notice Virtual balance mitigates 'share inflation' attacks.
     * The constant value balances between reducing initial depositor inflation and minimizing depositor losses.
     */
    uint256 internal constant BALANCE_OFFSET = 1e3;

    /// @notice The VaultManager contract.
    IVaultManager public vaultManager;

    /// @notice The underlying tokens of the Vault.
    IERC20 public underlyingToken;

    /// @notice The total amount of shares.
    uint256 public totalShares;

    modifier onlyVaultManager() {
        require(msg.sender == address(vaultManager), "Vault: caller is not the VaultManager");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(IVaultManager _vaultManager, IERC20 _underlyingToken) public virtual initializer {
        vaultManager = _vaultManager;
        _initializeBase(_underlyingToken);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @inheritdoc IVault
    function deposit(IERC20 token, uint256 amount, bool isYield)
        external
        virtual
        override
        onlyVaultManager
        returns (uint256)
    {
        _beforeDeposit(token, amount, isYield);

        uint256 priorTotalShares = totalShares;

        uint256 newShares = _previewDeposit(priorTotalShares, token, amount, isYield);

        require(newShares != 0, "Vault: newShare cannot be zero");
        totalShares = priorTotalShares + newShares;

        _afterDeposit(token, amount, isYield);

        return newShares;
    }

    /// @inheritdoc IVault
    function withdraw(IERC20 token, uint256 amountShares, address recipient)
        external
        virtual
        override
        onlyVaultManager
    {
        _beforeWithdraw(token, amountShares, recipient);

        uint256 priorTotalShares = totalShares;

        require(amountShares <= priorTotalShares, "Vault: amount exceeds total shares");

        uint256 virtualPriorTotalShares = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = totalAssets() + BALANCE_OFFSET;

        uint256 amountToSend = (amountShares * virtualTokenBalance) / virtualPriorTotalShares;

        totalShares = priorTotalShares - amountShares;

        _afterWithdraw(token, amountToSend, recipient);
    }

    /// @inheritdoc IVault
    function sharesToUnderlying(uint256 amountShares) public view virtual override returns (uint256) {
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = totalAssets() + BALANCE_OFFSET;

        return (virtualTokenBalance * amountShares) / virtualTotalShares;
    }

    /// @inheritdoc IVault
    function underlyingToShares(uint256 amountUnderlying) public view virtual override returns (uint256) {
        uint256 virtualTotalShares = totalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = totalAssets() + BALANCE_OFFSET;

        return (virtualTotalShares * amountUnderlying) / virtualTokenBalance;
    }

    /// @inheritdoc IVault
    function accountShares(address account) public view virtual override returns (uint256) {
        return vaultManager.vaultShares(account, IVault(address(this)));
    }

    /// @inheritdoc IVault
    function accountUnderlying(address account) public view virtual override returns (uint256) {
        return sharesToUnderlying(accountShares(account));
    }

    /// @inheritdoc IVault
    function totalAssets() public view virtual override returns (uint256) {
        return _totalAssets();
    }

    function _initializeBase(IERC20 _underlyingToken) internal onlyInitializing {
        underlyingToken = _underlyingToken;
    }

    function _totalAssets() internal view virtual returns (uint256) {
        return underlyingToken.balanceOf(address(this));
    }

    /**
     * @notice Preview the amount of new shares to issue for the deposit.
     * @param priorTotalShares The total amount of shares before the deposit.
     * @param token The token to deposit.
     * @param amount The amount of token to deposit.
     * @param isYield The flag to indicate if the deposit is in yield mode.
     */
    function _previewDeposit(uint256 priorTotalShares, IERC20 token, uint256 amount, bool isYield)
        internal
        view
        virtual
        returns (uint256)
    {
        uint256 virtualShareAmount = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = totalAssets() + BALANCE_OFFSET;

        uint256 virtualPriorTokenBalance = virtualTokenBalance - amount;
        uint256 newShares = (amount * virtualShareAmount) / virtualPriorTokenBalance;

        return newShares;
    }

    /**
     * @notice execute before token deposited in the vault.
     * @param token The token to be deposited.
     * @param amount The amount of the token to be deposited. This parameter is not used in the function but included for interface compatibility.
     * @param isYield A flag to indicate if the deposit is in yield mode. This parameter is not used in the function but included for interface compatibility.
     */
    function _beforeDeposit(IERC20 token, uint256 amount, bool isYield) internal virtual {
        require(token == underlyingToken, "Vault: token is not the underlying token");
    }

    /**
     * @notice execute after token deposited in the vault.
     * @param token The token to be deposited.
     * @param amount The amount of the token to be deposited.
     * @param isYield A flag to indicate if the deposit is in yield mode.
     */
    function _afterDeposit(IERC20 token, uint256 amount, bool isYield) internal virtual {
        // To be overridden by the derived contracts.
    }

    /**
     * @notice execute before token withdrawn from the vault.
     * @param token The token to be withdrawn.
     * @param amount The amount of the token to be withdrawn.
     * @param recipient The address to send the withdrawn tokens to.
     */
    function _beforeWithdraw(IERC20 token, uint256 amount, address recipient) internal virtual {
        require(token == underlyingToken, "Vault: token is not the underlying token");
    }

    /**
     * @notice execute after token withdrawn from the vault.
     * @param token The token to be withdrawn.
     * @param amount The amount of the token to be withdrawn.
     * @param recipient The address to send the withdrawn tokens to.
     */
    function _afterWithdraw(IERC20 token, uint256 amount, address recipient) internal virtual {
        token.safeTransfer(recipient, amount);
    }
}

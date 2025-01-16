// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseVault} from "./BaseVault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";
import {L2Encoder} from "aave-v3-origin/core/contracts/misc/L2Encoder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "aave-v3-origin/core/contracts/interfaces/IPool.sol";
import {IL2Pool} from "aave-v3-origin/core/contracts/interfaces/IL2Pool.sol";

/**
 * @title AaveVault
 * @dev This contract implements a yield-generating vault using the Aave protocol.
 *
 * It extends the BaseVault contract to enable users to deposit ERC20 tokens and earn yield through
 * Aave's lending mechanisms. The vault is designed to work seamlessly on both L1 and L2 networks,
 * with optimized calldata for L2 interactions via the L2Encoder.
 *
 * Key Features:
 * - Flexible support for both local storage of assets and direct interaction with the Aave protocol.
 * - Automatic handling of deposits and withdrawals, including L2-specific encoding for gas efficiency.
 * - Compatibility with Aave's aTokens to represent user balances within the protocol.
 * - Modular design to allow easy integration of new yield strategies or upgrades.
 *
 * Usage:
 * - Users can deposit supported tokens into the vault to start generating yield.
 * - Withdrawals return the deposited amount along with any accrued yield.
 *
 * Requirements:
 * - The vault must be initialized with a valid Aave Pool, aToken, and optional L2Encoder for L2 usage.
 * - Proper approval must be granted to the vault for managing user tokens.
 */
contract AaveVault is BaseVault {
    using SafeERC20 for IERC20;

    /// @notice The Aave Pool contract for managing deposits and withdrawals.
    address public aavePool;

    /// @notice The Aave aToken associated with the underlying token.
    IERC20 public aToken;

    /// @notice Encoder for L2 calldata optimization.
    L2Encoder public l2Encoder;

    /// @notice Flag indicating if the vault is on L2.
    bool public isL2;

    // @notice Emitted when assets are deposited into Aave for yield generation.
    event YieldDeposited(address indexed token, uint256 amount);
    // @notice Emitted when assets are withdrawn from the vault.
    event Withdrawn(address indexed token, uint256 amount, address recipient);

    /**
     * @notice Initializes the AaveVault contract.
     * @dev This function sets up the vault manager, underlying token, aToken, and Aave Pool.
     * It also grants approval for the Aave Pool to spend the underlying token.
     * @param _vaultManager The address of the vault manager contract.
     * @param _underlyingToken The underlying ERC20 token managed by this vault.
     * @param _aToken The Aave aToken corresponding to the underlying token.
     * @param _aavePool The address of the Aave Pool contract.
     * @param _isL2 Flag indicating if the vault is on L2.
     */
    function initialize(
        IVaultManager _vaultManager,
        IERC20 _underlyingToken,
        IERC20 _aToken,
        address _aavePool,
        bool _isL2,
        address _l2Encoder
    ) public initializer {
        require(address(_vaultManager) != address(0), "Vault: Invalid Vault Manager");
        require(address(_underlyingToken) != address(0), "Vault: Invalid underlying token");
        require(address(_aToken) != address(0), "Vault: Invalid aToken");
        require(_aavePool != address(0), "Vault: Invalid Aave Pool");

        BaseVault.initialize(_vaultManager, _underlyingToken);
        aavePool = _aavePool;
        aToken = _aToken;
        isL2 = _isL2;

        if (_isL2) {
            require(_l2Encoder != address(0), "Vault: Invalid L2 Encoder");
            l2Encoder = L2Encoder(_l2Encoder);
        }

        _underlyingToken.forceApprove(_aavePool, type(uint256).max);
    }

    /**
     * @notice Handles logic after a deposit is made.
     * @dev If the deposit is for yield, the tokens are supplied to Aave.
     * @param token The token being deposited.
     * @param amount The amount of tokens deposited.
     * @param isYield Indicates whether the deposit is for yield generation.
     */
    function _afterDeposit(IERC20 token, uint256 amount, bool isYield) internal override {
        if (isL2) {
            // Use L2Encoder to encode parameters for supply
            bytes32 encodedParams = l2Encoder.encodeSupplyParams(address(token), amount, 0);
            IL2Pool(aavePool).supply(encodedParams);
        } else {
            // Use standard Aave supply method
            IPool(aavePool).supply(address(token), amount, address(this), 0);
        }

        emit YieldDeposited(address(token), amount);
    }

    /**
     * @notice Handles logic after a withdrawal request is made.
     * @notice If the withdrawal amount exceeds the local balance, the remaining amount is withdrawn from Aave.
     * @dev Withdraws assets from either the local balance or the Aave protocol as needed.
     * @param token The token being withdrawn.
     * @param amount The amount of tokens to withdraw.
     * @param recipient The address receiving the withdrawn tokens.
     */
    function _afterWithdraw(IERC20 token, uint256 amount, address recipient) internal override {
        if (isL2) {
            // Use L2Encoder to encode parameters for withdraw
            bytes32 encodedParams = l2Encoder.encodeWithdrawParams(address(token), amount);

            // Withdraw tokens to the Vault contract
            IL2Pool(aavePool).withdraw(encodedParams);

            // Transfer tokens to the recipient.
            // Required for L2 since withdrawals from Aave are directed to the Vault itself.
            token.safeTransfer(recipient, amount);
        } else {
            // Use standard Aave withdraw method, which supports recipient
            IPool(aavePool).withdraw(address(token), amount, recipient);
        }

        emit Withdrawn(address(token), amount, recipient);
    }

    /**
     * @notice Computes the total assets managed by the vault.
     * @return The total assets, including local balance and yield in Aave.
     */
    function _totalAssets() internal view override returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    /**
     * @notice Calculates the number of shares to issue for a deposit.
     * @dev Adjusts logic based on whether the deposit is for yield or local storage.
     * @param priorTotalShares The total shares before the deposit.
     * @param token The token being deposited.
     * @param amount The amount of tokens to deposit.
     * @param isYield Indicates whether the deposit is for yield generation.
     * @return The number of new shares issued.
     */
    function _previewDeposit(uint256 priorTotalShares, IERC20 token, uint256 amount, bool isYield)
        internal
        view
        override
        returns (uint256)
    {
        uint256 virtualShareAmount = priorTotalShares + SHARES_OFFSET;
        uint256 virtualTokenBalance = totalAssets() + BALANCE_OFFSET;

        return (amount * virtualShareAmount) / virtualTokenBalance;
    }
}

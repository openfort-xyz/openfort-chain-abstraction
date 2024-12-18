// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVault} from "./IVault.sol";
import {IYieldVault} from "./IYieldVault.sol";

/**
 * @title Interface for the VaultManager contract.
 */
interface IVaultManager {
    /**
     * @notice Emitted when a deposit is made.
     * @param account The account that made the deposit.
     * @param token The token that was deposited.
     * @param vault The vault that was deposited into.
     * @param amount The amount of tokens that was deposited.
     * @param shares The amount of shares that was issued.
     */
    event Deposit(
        address indexed account,
        IERC20 indexed token,
        IVault indexed vault,
        uint256 amount,
        uint256 shares
    );

    /**
     * @notice Emitted when a withdrawal is queued.
     * @param account The account that queued the withdrawal.
     * @param vaults The vaults that were withdrawn from.
     * @param shares The amount of shares that were withdrawn.
     * @param withdrawalId The ID of the withdrawal.
     */
    event WithdrawalQueued(
        address indexed account,
        IVault[] vaults,
        uint256[] shares,
        bytes32 indexed withdrawalId
    );

    /**
     * @notice Emitted when a withdrawal is completed.
     * @param account The account that completed the withdrawal.
     * @param vaults The vaults that were withdrawn from.
     * @param shares The amount of shares that were withdrawn.
     * @param withdrawalId The ID of the withdrawal.
     */
    event WithdrawalCompleted(
        address indexed account,
        IVault[] vaults,
        uint256[] shares,
        bytes32 indexed withdrawalId
    );

    /**
     * @notice Emitted when locked tokens are withdrawn.
     * @param account The account that withdrew the tokens.
     * @param vaults The vaults that were withdrawn from.
     * @param amounts The amounts of tokens that were withdrawn.
     */
    event WithdrawSponsorToken(
        address indexed account,
        IVault[] vaults,
        uint256[] amounts
    );

    /**
     * @notice Emitted when a deposit to yield is made.
     * @param account The account that made the deposit.
     * @param vault The vault that was deposited into.
     * @param shares The amount of shares that was issued.
     */
    event DepositToYield(
        address indexed account,
        IYieldVault indexed vault,
        uint256 shares,
        uint256 yieldShares
    );

    /// @notice Struct to represent the withdrawal request.
    struct Withdrawal {
        address account;
        IVault[] vaults;
        uint256[] amounts;
        uint256 startBlock;
        uint256 nonce;
        bool completed;
    }

    /**
     * @notice Add a new Vault to the VaultManager.
     * @dev The function is only callable by the owner.
     * @param vault The Vault to add.
     */
    function addVault(IVault vault) external;

    /**
     * @notice Deposit the specified amount of tokens into the Vault.
     * @param token The token to deposit.
     * @param vault The Vault to deposit into.
     * @param amount The amount of tokens to deposit.
     * @param isYield A flag to indicate if the deposit is in yield mode.
     * @return shares The amount of shares issued at the current exchange rate.
     */
    function deposit(
        IERC20 token,
        IVault vault,
        uint256 amount,
        bool isYield
    ) external returns (uint256);

    /**
     * @notice Withdraw the specified amount of tokens from the Vault.
     * @param vaults The Vaults to withdraw from.
     * @param shares The amount of shares to withdraw.
     * @param withdrawer The address to send the withdrawn tokens to.
     * @return withdrawalId The ID of the withdrawal request.
     */
    function queueWithdrawals(
        IVault[] calldata vaults,
        uint256[] calldata shares,
        address withdrawer
    ) external returns (bytes32);

    /**
     * @notice Complete the specified withdrawals.
     * @param withdrawalIds The IDs of the withdrawals to complete.
     */
    function completeWithdrawals(bytes32[] calldata withdrawalIds) external;

    /**
     * @notice Deposit the tokens from yield vault into the Yield strategy.
     * @param vault The Yield Vault to deposit into.
     * @return shares The amount of shares rewarded to the depositer.
     */
    function depositToYield(
        IERC20 token,
        IYieldVault vault,
        uint256 amount,
        bool isYield
    ) external returns (uint256, uint256);

    /**
     * @notice Withdraw the specified amount of tokens to the receiver.
     * @dev The function is only callable by the invoiceManager contract.
     * @param account The account to repay.
     * @param vaults The vaults to repay.
     * @param amounts The amounts of underlying tokens to repay.
     * @param receiver The address to send the repaid tokens to.
     */
    function withdrawSponsorToken(
        address account,
        IVault[] calldata vaults,
        uint256[] calldata amounts,
        address receiver
    ) external;

    /**
     * @notice Returns the amount of shares for the account in the specified vault.
     * @param account The account to query.
     * @param vault The vault to query.
     * @return shares The amount of shares for the account.
     */
    function vaultShares(
        address account,
        IVault vault
    ) external view returns (uint256);

    /**
     * @notice Returns the amount of underlying tokens for the account in the specified vault.
     * @param account The account to query.
     * @param token The token to query.
     * @return underlying The amount of underlying tokens for the account.
     */
    function getAccountTokenBalance(
        address account,
        IERC20 token
    ) external view returns (uint256);

    /**
     * @notice Returns the list of Vaults with the underlying token.
     * @param token The token to query.
     * @return vaults The list of Vaults with the underlying token.
     */
    function getUnderlyingToVaultList(
        IERC20 token
    ) external view returns (IVault[] memory);

    /**
     * @notice Returns the nonce for the account withdrawal.
     * @param account The account to query.
     * @return nonce The nonce for the account withdrawal.
     */
    function getWithdrawalNonce(
        address account
    ) external view returns (uint256);

    /**
     * @notice Returns the pending withdrawals for the account.
     * @param withdrawId The ID of the withdrawal request.
     * @return withdrawal The pending withdrawals for the account.
     */
    function getWithdrawal(
        bytes32 withdrawId
    ) external view returns (Withdrawal memory);
}

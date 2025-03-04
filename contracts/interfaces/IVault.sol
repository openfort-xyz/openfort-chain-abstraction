// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Interface for the Vault contract.
 */
interface IVault {
    /**
     * @notice Deposits the specified amount of tokens into the Vault.
     * @dev The function is only callable by vaultManager contract.
     * @param token The token to deposit.
     * @param amount The amount of tokens to deposit.
     * @param isYield A flag to indicate if the deposit is in yield mode.
     * @return newShares The amount of new shares issue at the current exchange rate.
     */
    function deposit(IERC20 token, uint256 amount, bool isYield) external returns (uint256);

    /**
     * @notice Withdraws the specified amount of tokens from the Vault.
     * @dev The function is only callable by vaultManager contract.
     * @param token The token to withdraw.
     * @param amountShare The amount of shares to withdraw.
     * @param recipient The address to send the withdrawn tokens to.
     */
    function withdraw(IERC20 token, uint256 amountShare, address recipient) external;

    /**
     * @notice Convert the specified amount of shares to the underlying token.
     * @param amountShares The amount of shares.
     * @return amountUnderlying The amount of token corresponding to the shares.
     */
    function sharesToUnderlying(uint256 amountShares) external view returns (uint256);

    /**
     * @notice Convert the specified amount of underlying token to shares.
     * @param amountUnderlying The amount of underlying tokens.
     * @return amountShares The amount of shares corresponding to the underlying amount.
     */
    function underlyingToShares(uint256 amountUnderlying) external view returns (uint256);

    /**
     * @notice Returns the total amount of shares for the account.
     * @param account The account to query.
     * @return shares The amount of shares for the account.
     */
    function accountShares(address account) external view returns (uint256);

    /**
     * @notice Returns the total amount of underlying tokens for the account.
     * @param account The account to query.
     * @return underlying The amount of underlying tokens for the account.
     */
    function accountUnderlying(address account) external view returns (uint256);

    /**
     * @notice Returns the underlying token of the Vault.
     * @return token The underlying token.
     */
    function underlyingToken() external view returns (IERC20);

    /**
     * @notice Returns the total amount of shares in the Vault.
     * @return totalShares The total amount of shares in the Vault.
     */
    function totalShares() external view returns (uint256);

    /**
     * @notice Returns the total amount of balance in the Vault.
     * @return totalAssets The total balance of the Vault.
     */
    function totalAssets() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IVaultManager} from "../interfaces/IVaultManager.sol";

contract VaultManager is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IVaultManager {
    using SafeERC20 for IERC20;

    IInvoiceManager public invoiceManager;
    uint256 public withdrawLockBlock;

    /// @notice Mapping: Vault => bool to indicate if the Vault is registered.
    mapping(IVault => bool) public registeredVaults;

    /// @notice Mapping: Account => Vault[] to store the list of Vaults for the account.
    mapping(address => IVault[]) public accountVaultList;

    /// @notice Mapping: Underlying => Vault[] to store the list of Vaults for the underlying token.
    mapping(IERC20 => IVault[]) public underlyingToVaultList;

    /// @notice Mapping: Account => Vault => uint256 to store the account shares for the Vault.
    mapping(address => mapping(IVault => uint256)) public accountShares;

    /// @notice Mapping: Account => uint256 to store the account nonce for withdrawal.
    mapping(address => uint256) public withdrawalNonces;

    /// @notice Mapping: bytes32 => Withdrawal to store the withdrawal request.
    mapping(bytes32 => Withdrawal) public withdrawals;

    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    modifier onlyRegisteredVault(IVault vault) {
        require(registeredVaults[vault], "VaultManager: vault not registered");
        _;
    }

    modifier onlyInvoiceManager() {
        require(msg.sender == address(invoiceManager), "VaultManager: caller is not the InvoiceManager");
        _;
    }

    function initialize(address initialOwner, IInvoiceManager _invoiceManager, uint256 _withdrawLockBlock)
        public
        virtual
        initializer
    {
        invoiceManager = _invoiceManager;
        withdrawLockBlock = _withdrawLockBlock;
        _transferOwnership(initialOwner);
        __ReentrancyGuard_init();
    }

    /// @inheritdoc IVaultManager
    function addVault(IVault vault) external override onlyOwner {
        registeredVaults[vault] = true;

        IERC20 underlying = vault.underlyingToken();
        underlyingToVaultList[underlying].push(vault);
    }

    /// @inheritdoc IVaultManager
    function deposit(IERC20 token, IVault vault, uint256 amount, bool isYield)
        external
        override
        onlyRegisteredVault(vault)
        nonReentrant
        returns (uint256 newShare)
    {
        token.safeTransferFrom(msg.sender, address(vault), amount);

        newShare = vault.deposit(token, amount, isYield);

        _addShare(msg.sender, vault, newShare);

        emit Deposit(msg.sender, token, vault, amount, newShare);
    }

    /// @inheritdoc IVaultManager
    function queueWithdrawals(IVault[] calldata vaults, uint256[] calldata shares, address withdrawer)
        external
        override
        nonReentrant
        returns (bytes32 withdrawalId)
    {
        require(vaults.length == shares.length, "VaultManager: invalid input length");
        require(withdrawer == msg.sender, "VaultManager: caller is not the withdrawer");

        for (uint256 i = 0; i < vaults.length; i++) {
            IVault vault = vaults[i];
            uint256 share = shares[i];

            require(registeredVaults[vault], "VaultManager: vault not registered");
            require(accountShares[withdrawer][vault] >= share, "VaultManager: insufficient shares");
        }
        uint256 withdrawNonce = withdrawalNonces[withdrawer];
        withdrawalId = keccak256(abi.encodePacked(withdrawer, withdrawNonce));

        withdrawals[withdrawalId] = Withdrawal(withdrawer, vaults, shares, block.number, withdrawNonce, false);
        withdrawalNonces[withdrawer] = withdrawNonce + 1;

        emit WithdrawalQueued(withdrawer, vaults, shares, withdrawalId);
    }

    /// @inheritdoc IVaultManager
    function completeWithdrawals(bytes32[] calldata withdrawalIds) external override nonReentrant {
        for (uint256 i = 0; i < withdrawalIds.length; i++) {
            bytes32 withdrawalId = withdrawalIds[i];
            Withdrawal storage withdrawal = withdrawals[withdrawalId];

            require(!withdrawal.completed, "VaultManager: withdrawal already completed");
            require(withdrawal.account == msg.sender, "VaultManager: caller is not the withdrawer");
            require(block.number >= withdrawal.startBlock + withdrawLockBlock, "VaultManager: withdrawal not ready");

            for (uint256 j = 0; j < withdrawal.vaults.length; j++) {
                IVault vault = withdrawal.vaults[j];
                uint256 share = withdrawal.amounts[j];

                _removeShare(msg.sender, vault, share);
                vault.withdraw(vault.underlyingToken(), share, msg.sender);
            }

            withdrawal.completed = true;
            emit WithdrawalCompleted(msg.sender, withdrawal.vaults, withdrawal.amounts, withdrawalId);
        }
    }

    /// @inheritdoc IVaultManager
    function withdrawSponsorToken(
        address account,
        IVault[] calldata vaults,
        uint256[] calldata amounts,
        address receiver
    ) external override nonReentrant onlyInvoiceManager {
        require(vaults.length == amounts.length, "VaultManager: invalid input length");

        for (uint256 i = 0; i < vaults.length; i++) {
            IVault vault = vaults[i];
            uint256 amount = amounts[i];

            uint256 amountShare = vault.underlyingToShares(amount);
            _removeShare(account, vault, amountShare);
            IERC20 underlying = IERC20(vault.underlyingToken());
            vault.withdraw(underlying, amountShare, receiver);
        }

        emit WithdrawSponsorToken(account, vaults, amounts);
    }

    /// @inheritdoc IVaultManager
    function vaultShares(address account, IVault vault) external view override returns (uint256) {
        return accountShares[account][vault];
    }

    /// @inheritdoc IVaultManager
    function getAccountTokenBalance(address account, IERC20 token) external view override returns (uint256 balance) {
        IVault[] memory vaults = accountVaultList[account];
        for (uint256 i = 0; i < vaults.length; i++) {
            IVault vault = vaults[i];
            if (vault.underlyingToken() == token) {
                uint256 shares = accountShares[account][vault];
                balance += vault.sharesToUnderlying(shares);
            }
        }
    }

    /// @inheritdoc IVaultManager
    function getUnderlyingToVaultList(IERC20 token) external view override returns (IVault[] memory) {
        return underlyingToVaultList[token];
    }

    /// @inheritdoc IVaultManager
    function getWithdrawalNonce(address account) external view returns (uint256) {
        return withdrawalNonces[account];
    }

    /// @inheritdoc IVaultManager
    function getWithdrawal(bytes32 withdrawalId) external view returns (Withdrawal memory) {
        return withdrawals[withdrawalId];
    }

    function _addShare(address account, IVault vault, uint256 amount) internal {
        // sanity check
        require(amount != 0, "VaultManager: share cannot be zero");

        // add the vault to the account's vault list if the account has no shares in the vault
        if (accountShares[account][vault] == 0) {
            accountVaultList[account].push(vault);
        }

        // update the account shares
        accountShares[account][vault] += amount;
    }

    function _removeShare(address account, IVault vault, uint256 amountShare) internal {
        // sanity check
        require(amountShare != 0, "VaultManager: share cannot be zero");

        uint256 share = accountShares[account][vault];
        require(share >= amountShare, "VaultManager: insufficient shares");

        unchecked {
            share = share - amountShare;
        }

        // update the account shares
        accountShares[account][vault] = share;

        // remove the vault from the account's vault list if the account has no shares in the vault
        if (share == 0) {
            _removeAccountVaultList(account, vault);
        }
    }

    function _removeAccountVaultList(address account, IVault vault) internal {
        uint256 listLength = accountVaultList[account].length;
        uint256 i = 0;
        for (; i < listLength;) {
            if (accountVaultList[account][i] == vault) {
                accountVaultList[account][i] = accountVaultList[account][listLength - 1];
                accountVaultList[account].pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }
}

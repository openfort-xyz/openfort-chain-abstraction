// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../contracts/interfaces/IInvoiceManager.sol";
import {IVault} from "../contracts/interfaces/IVault.sol";
import {IVaultManager} from "../contracts/interfaces/IVaultManager.sol";
import {IYieldVault} from "../contracts/interfaces/IYieldVault.sol";

import {MockERC20} from "../contracts/mocks/MockERC20.sol";
import {MockInvoiceManager} from "../contracts/mocks/MockInvoiceManager.sol";
import {UpgradeableOpenfortProxy} from "../contracts/proxy/UpgradeableOpenfortProxy.sol";
import {BaseVault} from "../contracts/vaults/BaseVault.sol";
import {VaultManager} from "../contracts/vaults/VaultManager.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

contract VaultManagerTest is Test {
    VaultManager public vaultManager;

    address public owner;
    address public user1;
    address public user2;
    MockERC20 public mockERC20;
    BaseVault public vault;
    MockInvoiceManager public invoiceManager;
    uint256 public constant WITHDRAW_LOCK_BLOCK = 10;

    function setUp() public {
        owner = makeAddr("OWNER");
        user1 = makeAddr("USER1");
        user2 = makeAddr("USER2");

        // Deploy mock tokens and contracts
        mockERC20 = new MockERC20();
        invoiceManager = new MockInvoiceManager();

        // Deploy VaultManager through proxy
        vaultManager = VaultManager(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new VaultManager()),
                    abi.encodeWithSelector(
                        VaultManager.initialize.selector, owner, IInvoiceManager(address(invoiceManager)), WITHDRAW_LOCK_BLOCK
                    )
                )
            )
        );

        // Deploy BaseVault through proxy
        vault = BaseVault(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new BaseVault()),
                    abi.encodeWithSelector(BaseVault.initialize.selector, IVaultManager(address(vaultManager)), mockERC20)
                )
            )
        );

        // Register vault in VaultManager
        vm.startPrank(owner);
        vaultManager.addVault(IVault(address(vault)));
        vm.stopPrank();

        // Mint tokens to users for testing
        mockERC20.mint(user1, 1000);
        mockERC20.mint(user2, 1000);
    }

    function testInitialization() public {
        assertEq(address(vaultManager.invoiceManager()), address(invoiceManager));
        assertEq(vaultManager.withdrawLockBlock(), WITHDRAW_LOCK_BLOCK);
        assertEq(vaultManager.owner(), owner);
        assertTrue(vaultManager.registeredVaults(IVault(address(vault))));
    }

    function testAddVault() public {
        // Deploy a new vault
        BaseVault newVault = BaseVault(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new BaseVault()),
                    abi.encodeWithSelector(BaseVault.initialize.selector, IVaultManager(address(vaultManager)), mockERC20)
                )
            )
        );

        // Add the new vault
        vm.startPrank(owner);
        vaultManager.addVault(IVault(address(newVault)));
        vm.stopPrank();

        // Verify the vault was added
        assertTrue(vaultManager.registeredVaults(IVault(address(newVault))));

        // Check that the vault is in the underlyingToVaultList
        IVault[] memory vaults = vaultManager.getUnderlyingToVaultList(mockERC20);
        assertEq(vaults.length, 2);
        assertEq(address(vaults[0]), address(vault));
        assertEq(address(vaults[1]), address(newVault));
    }

    function testDeposit() public {
        uint256 depositAmount = 100;

        // Approve tokens for VaultManager
        vm.startPrank(user1);
        mockERC20.approve(address(vaultManager), depositAmount);

        // Deposit tokens
        uint256 newShares = vaultManager.deposit(mockERC20, IVault(address(vault)), depositAmount, false);
        vm.stopPrank();

        // Verify shares were added to the user
        assertEq(vaultManager.accountShares(user1, IVault(address(vault))), newShares);

        // Verify tokens were transferred to the vault
        assertEq(mockERC20.balanceOf(address(vault)), depositAmount);

        // Verify user's vault list contains the vault
        IVault userVaults = vaultManager.accountVaultList(user1, 0);
        assertEq(address(userVaults), address(vault));
    }

    function testDepositFor() public {
        uint256 depositAmount = 100;

        // Approve tokens for VaultManager
        vm.startPrank(user1);
        mockERC20.approve(address(vaultManager), depositAmount);

        // Deposit tokens for user2
        uint256 newShares = vaultManager.depositFor(user2, mockERC20, IVault(address(vault)), depositAmount, false);
        vm.stopPrank();

        // Verify shares were added to user2
        assertEq(vaultManager.accountShares(user2, IVault(address(vault))), newShares);

        // Verify tokens were transferred to the vault
        assertEq(mockERC20.balanceOf(address(vault)), depositAmount);

        // Verify user2's vault list contains the vault
        IVault userVaults = vaultManager.accountVaultList(user2, 0);
        assertEq(address(userVaults), address(vault));
    }

    function testQueueWithdrawals() public {
        uint256 depositAmount = 100;

        // Deposit tokens first
        vm.startPrank(user1);
        mockERC20.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(mockERC20, IVault(address(vault)), depositAmount, false);

        // Queue withdrawal
        IVault[] memory vaults = new IVault[](1);
        vaults[0] = IVault(address(vault));

        uint256[] memory shares = new uint256[](1);
        shares[0] = vaultManager.accountShares(user1, IVault(address(vault)));

        bytes32 withdrawalId = vaultManager.queueWithdrawals(vaults, shares, user1);
        vm.stopPrank();

        // Verify withdrawal was queued
        IVaultManager.Withdrawal memory withdrawal = vaultManager.getWithdrawal(withdrawalId);
        assertEq(withdrawal.account, user1);
        assertEq(address(withdrawal.vaults[0]), address(vault));
        assertEq(withdrawal.amounts[0], shares[0]);
        assertEq(withdrawal.startBlock, block.number);
        assertEq(withdrawal.nonce, 0);
        assertFalse(withdrawal.completed);

        // Verify nonce was incremented
        assertEq(vaultManager.getWithdrawalNonce(user1), 1);
    }

    function testCompleteWithdrawals() public {
        uint256 depositAmount = 100;

        // Deposit tokens first
        vm.startPrank(user1);
        mockERC20.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(mockERC20, IVault(address(vault)), depositAmount, false);

        // Queue withdrawal
        IVault[] memory vaults = new IVault[](1);
        vaults[0] = IVault(address(vault));

        uint256[] memory shares = new uint256[](1);
        shares[0] = vaultManager.accountShares(user1, IVault(address(vault)));

        bytes32 withdrawalId = vaultManager.queueWithdrawals(vaults, shares, user1);

        // Try to complete withdrawal before lock period
        vm.expectRevert("VaultManager: withdrawal not ready");
        bytes32[] memory withdrawalIds = new bytes32[](1);
        withdrawalIds[0] = withdrawalId;
        vaultManager.completeWithdrawals(withdrawalIds);

        // Advance blocks to pass lock period
        vm.roll(block.number + WITHDRAW_LOCK_BLOCK + 1);

        // Complete withdrawal
        vaultManager.completeWithdrawals(withdrawalIds);
        vm.stopPrank();

        // Verify withdrawal was completed
        IVaultManager.Withdrawal memory withdrawal = vaultManager.getWithdrawal(withdrawalId);
        assertTrue(withdrawal.completed);

        // Verify shares were removed
        assertEq(vaultManager.accountShares(user1, IVault(address(vault))), 0);

        // Verify tokens were transferred back to user
        assertEq(mockERC20.balanceOf(user1), 1000);
    }

    function testWithdrawSponsorToken() public {
        uint256 depositAmount = 100;

        // Deposit tokens first
        vm.startPrank(user1);
        mockERC20.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(mockERC20, IVault(address(vault)), depositAmount, false);
        vm.stopPrank();

        // Prepare withdrawal data
        IVault[] memory vaults = new IVault[](1);
        vaults[0] = IVault(address(vault));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50; // Withdraw half of the deposit

        // Only InvoiceManager can call withdrawSponsorToken
        vm.startPrank(address(invoiceManager));
        vaultManager.withdrawSponsorToken(user1, vaults, amounts, user2);
        vm.stopPrank();

        // Verify shares were reduced
        uint256 remainingShares = vaultManager.accountShares(user1, IVault(address(vault)));
        assertTrue(remainingShares > 0 && remainingShares < vault.underlyingToShares(depositAmount));

        // Verify tokens were transferred to user2
        assertEq(mockERC20.balanceOf(user2), 1050);
    }

    function testGetAccountTokenBalance() public {
        uint256 depositAmount = 100;

        // Deposit tokens
        vm.startPrank(user1);
        mockERC20.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(mockERC20, IVault(address(vault)), depositAmount, false);
        vm.stopPrank();

        // Get account token balance
        uint256 balance = vaultManager.getAccountTokenBalance(user1, mockERC20);

        // Should be approximately equal to deposit amount (might be slightly less due to share calculation)
        assertApproxEqAbs(balance, depositAmount, 1);
    }

    function testMultipleDepositsAndWithdrawals() public {
        // User1 deposits
        vm.startPrank(user1);
        mockERC20.approve(address(vaultManager), 500);
        vaultManager.deposit(mockERC20, IVault(address(vault)), 200, false);
        vaultManager.deposit(mockERC20, IVault(address(vault)), 300, false);
        vm.stopPrank();

        // User2 deposits
        vm.startPrank(user2);
        mockERC20.approve(address(vaultManager), 400);
        vaultManager.deposit(mockERC20, IVault(address(vault)), 400, false);
        vm.stopPrank();

        // Verify total assets in vault
        assertEq(vault.totalAssets(), 900);

        // User1 queues partial withdrawal
        vm.startPrank(user1);
        IVault[] memory vaults = new IVault[](1);
        vaults[0] = IVault(address(vault));

        uint256[] memory shares = new uint256[](1);
        shares[0] = vault.underlyingToShares(150);

        bytes32 withdrawalId = vaultManager.queueWithdrawals(vaults, shares, user1);
        vm.stopPrank();

        // Advance blocks
        vm.roll(block.number + WITHDRAW_LOCK_BLOCK + 1);

        // Complete withdrawal
        vm.startPrank(user1);
        bytes32[] memory withdrawalIds = new bytes32[](1);
        withdrawalIds[0] = withdrawalId;
        vaultManager.completeWithdrawals(withdrawalIds);
        vm.stopPrank();

        // Verify balances
        uint256 user1Balance = vaultManager.getAccountTokenBalance(user1, mockERC20);
        uint256 user2Balance = vaultManager.getAccountTokenBalance(user2, mockERC20);

        assertApproxEqAbs(user1Balance, 350, 1);
        assertApproxEqAbs(user2Balance, 400, 1);
        assertApproxEqAbs(vault.totalAssets(), 750, 1);
    }

    function testOnlyOwnerCanAddVault() public {
        BaseVault newVault = BaseVault(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new BaseVault()),
                    abi.encodeWithSelector(BaseVault.initialize.selector, IVaultManager(address(vaultManager)), mockERC20)
                )
            )
        );

        // Non-owner tries to add vault
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        vaultManager.addVault(IVault(address(newVault)));
        vm.stopPrank();

        // Owner adds vault
        vm.startPrank(owner);
        vaultManager.addVault(IVault(address(newVault)));
        vm.stopPrank();

        assertTrue(vaultManager.registeredVaults(IVault(address(newVault))));
    }

    function testOnlyInvoiceManagerCanWithdrawSponsorToken() public {
        uint256 depositAmount = 100;

        // Deposit tokens first
        vm.startPrank(user1);
        mockERC20.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(mockERC20, IVault(address(vault)), depositAmount, false);
        vm.stopPrank();

        // Prepare withdrawal data
        IVault[] memory vaults = new IVault[](1);
        vaults[0] = IVault(address(vault));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        // Non-InvoiceManager tries to call withdrawSponsorToken
        vm.startPrank(user2);
        vm.expectRevert("VaultManager: caller is not the InvoiceManager");
        vaultManager.withdrawSponsorToken(user1, vaults, amounts, user2);
        vm.stopPrank();
    }
}

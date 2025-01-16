// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {VaultManager} from "../../src/vaults/VaultManager.sol";
import {AaveVault} from "../../src/vaults/AaveVault.sol";
import {UpgradeableOpenfortProxy} from "../../src/proxy/UpgradeableOpenfortProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "aave-v3-origin/core/contracts/interfaces/IPool.sol";
import {InvoiceManager} from "../../src/core/InvoiceManager.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {CheckAaveTokenStatus} from "../../script/auxiliary/checkAaveTokenStatus.s.sol";
import {L2Encoder} from "aave-v3-origin/core/contracts/misc/L2Encoder.sol";

contract DeployAndTestAaveVaults is Test, Script, CheckAaveTokenStatus {
    VaultManager internal vaultManager;
    AaveVault internal aaveVault;
    InvoiceManager internal invoiceManager;
    IERC20 internal underlyingToken;
    IERC20 internal aToken;
    address internal deployer;
    address internal l2Encoder;

    bool internal isL2 = vm.envBool("IS_L2");
    address internal owner = vm.envAddress("OWNER");
    address internal aavePool = vm.envAddress("AAVE_POOL");
    address internal protocolDataProvider = vm.envAddress("AAVE_DATA_PROVIDER");
    address internal underlyingTokenAddress = vm.envAddress("UNDERLYING_TOKEN");

    function setUp() public {
        deployer = owner;
        underlyingToken = IERC20(underlyingTokenAddress);
        invoiceManager = InvoiceManager(payable(new UpgradeableOpenfortProxy(address(new InvoiceManager()), "")));

        vaultManager = VaultManager(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new VaultManager()),
                    abi.encodeWithSelector(VaultManager.initialize.selector, owner, address(invoiceManager), 10)
                )
            )
        );

        if (isAaveToken(protocolDataProvider, address(underlyingToken))) {
            if (isL2) {
                l2Encoder = address(new L2Encoder(IPool(aavePool)));
            } else {
                l2Encoder = address(0);
            }
            address aTokenAddress = getATokenAddress(protocolDataProvider, address(underlyingToken));
            aToken = IERC20(aTokenAddress);
            aaveVault = AaveVault(
                address(
                    new UpgradeableOpenfortProxy(
                        address(new AaveVault()),
                        abi.encodeWithSelector(
                            AaveVault.initialize.selector,
                            address(vaultManager),
                            underlyingToken,
                            aToken,
                            IPool(aavePool),
                            isL2,
                            l2Encoder
                        )
                    )
                )
            );
        }
    }

    function testIsAaveToken() public view {
        bool tokenIsActive = isAaveToken(protocolDataProvider, address(underlyingToken));
        assertTrue(tokenIsActive, "Underlying token is not active in Aave");
    }

    function testGetATokenAddress() public view {
        address aTokenAddress = getATokenAddress(protocolDataProvider, address(underlyingToken));
        assertTrue(aTokenAddress != address(underlyingToken), "aToken address is invalid");
    }

    // E2E test for a user deposit and withdrawal, make time advance to check that yield is generated
    function testE2EAaveVault() public {
        vm.startPrank(owner);

        uint256 initialDeployerDAIBalance = underlyingToken.balanceOf(deployer);

        vaultManager.addVault(aaveVault);
        bool isRegistered = vaultManager.registeredVaults(aaveVault);
        assertTrue(isRegistered, "Vault was not added successfully");

        uint256 depositAmount = 100 * 10 ** 18; // 100 DAI
        underlyingToken.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(underlyingToken, aaveVault, depositAmount, true);

        uint256 postDepositVaultaTokenBalance = aToken.balanceOf(address(aaveVault));
        uint256 userShares = vaultManager.vaultShares(owner, aaveVault);

        uint256 tolerance = 1;
        assertApproxEqAbs(
            postDepositVaultaTokenBalance, depositAmount, tolerance, "Vault aToken balance mismatch after deposit"
        );
        assertEq(userShares, depositAmount, "User shares mismatch after deposit");

        uint256 withdrawAmount = 100 * 10 ** 18;
        uint256 sharesWithdrawAmount = aaveVault.underlyingToShares(withdrawAmount);

        IVault[] memory vaults = new IVault[](1);
        vaults[0] = aaveVault;

        uint256[] memory sharesToWithdraw = new uint256[](1);
        sharesToWithdraw[0] = sharesWithdrawAmount;

        uint256 withdrawLockBlock = vaultManager.withdrawLockBlock();
        vm.roll(block.number + withdrawLockBlock + 1000);

        bytes32 withdrawalId = vaultManager.queueWithdrawals(vaults, sharesToWithdraw, deployer);

        bytes32[] memory withdrawalIds = new bytes32[](1);
        withdrawalIds[0] = withdrawalId;

        // Advance time for yield accrual
        uint256 oneYearInSeconds = 365 days;
        vm.warp(block.timestamp + oneYearInSeconds);
        vm.roll(block.number + 1000);

        vaultManager.completeWithdrawals(withdrawalIds);

        uint256 finalDeployerDAIBalance = underlyingToken.balanceOf(deployer);

        // Calculate and log yield
        uint256 yieldEarned = finalDeployerDAIBalance - initialDeployerDAIBalance;
        assertGt(yieldEarned, 0, "No yield earned");
        assertEq(finalDeployerDAIBalance, initialDeployerDAIBalance + yieldEarned, "Incorrect final DAI balance");

        vm.stopPrank();
    }

    function testSharesDistribution() public {
        vm.startPrank(owner);

        vaultManager.addVault(aaveVault);
        assertTrue(vaultManager.registeredVaults(aaveVault), "Vault was not registered");

        uint256 ownerDeposit = 100 * 10 ** 18; // 100 DAI
        underlyingToken.approve(address(vaultManager), ownerDeposit);
        vaultManager.deposit(underlyingToken, aaveVault, ownerDeposit, true);

        uint256 ownerShares = vaultManager.vaultShares(owner, aaveVault);
        assertEq(ownerShares, ownerDeposit, "Owner shares mismatch after deposit");

        vm.stopPrank();

        address user = 0x60C7A23B85903EE6B5598e2800865E0AC35d94f9;
        uint256 userInitialBalance = underlyingToken.balanceOf(user);

        vm.startPrank(user);
        underlyingToken.transfer(user, ownerDeposit / 2);
        underlyingToken.approve(address(vaultManager), ownerDeposit / 2);
        vaultManager.deposit(underlyingToken, aaveVault, ownerDeposit / 2, true);

        uint256 userShares = vaultManager.vaultShares(user, aaveVault);
        assertEq(userShares, ownerDeposit / 2, "User shares mismatch after deposit");

        uint256 totalShares = aaveVault.totalShares();
        assertEq(totalShares, ownerShares + userShares, "Total shares mismatch");

        uint256 withdrawLockBlock = vaultManager.withdrawLockBlock();
        vm.warp(block.timestamp + 355 days);
        vm.roll(block.number + withdrawLockBlock + 10);

        uint256 withdrawAmount = 10 * 10 ** 18;
        uint256 sharesWithdrawAmount = aaveVault.underlyingToShares(withdrawAmount);

        IVault[] memory vaults = new IVault[](1);
        vaults[0] = aaveVault;

        uint256[] memory sharesToWithdraw = new uint256[](1);
        sharesToWithdraw[0] = sharesWithdrawAmount;

        bytes32 withdrawalId = vaultManager.queueWithdrawals(vaults, sharesToWithdraw, user);
        vm.roll(block.number + withdrawLockBlock + 12);

        bytes32[] memory withdrawalIds = new bytes32[](1);
        withdrawalIds[0] = withdrawalId;

        vaultManager.completeWithdrawals(withdrawalIds);

        uint256 userFinalBalance = underlyingToken.balanceOf(user);

        // should do more precise calculations, however this ensure that user wants to withdraw 10 Dai
        // (initial deposit 100 Dai) and when withdraws its balance is greater then the initial.
        assertGt(userFinalBalance + 90 * 10 ** 18, userInitialBalance, "Yield was not earned on withdrawal");
        vm.stopPrank();
    }

    function testPartialWithdraw() public {
        vm.startPrank(owner);

        vaultManager.addVault(aaveVault);
        uint256 initialBalance = underlyingToken.balanceOf(owner);
        uint256 depositAmount = 100 * 10 ** 18;

        underlyingToken.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(underlyingToken, aaveVault, depositAmount, true);

        uint256 withdrawAmount = 40 * 10 ** 18;
        uint256 sharesWithdrawAmount = aaveVault.underlyingToShares(withdrawAmount);

        IVault[] memory vaults = new IVault[](1);
        vaults[0] = aaveVault;

        uint256[] memory sharesToWithdraw = new uint256[](1);
        sharesToWithdraw[0] = sharesWithdrawAmount;

        uint256 withdrawLockBlock = vaultManager.withdrawLockBlock();
        vm.roll(block.number + withdrawLockBlock + 1);

        bytes32 withdrawalId = vaultManager.queueWithdrawals(vaults, sharesToWithdraw, owner);

        bytes32[] memory withdrawalIds = new bytes32[](1);
        withdrawalIds[0] = withdrawalId;

        vm.roll(block.number + withdrawLockBlock + 2);

        vaultManager.completeWithdrawals(withdrawalIds);

        uint256 newBalance = underlyingToken.balanceOf(owner);
        uint256 remainingShares = vaultManager.vaultShares(owner, aaveVault);

        // Check that 40 DAI was withdrawn, and the remaining shares are correct
        assertEq(newBalance, initialBalance - depositAmount + withdrawAmount, "Partial withdraw failed");
        assertEq(remainingShares, depositAmount - withdrawAmount, "Remaining shares mismatch");

        vm.stopPrank();
    }

    function testZeroDeposit() public {
        vm.startPrank(owner);

        vaultManager.addVault(aaveVault);

        uint256 depositAmount = 0;
        underlyingToken.approve(address(vaultManager), depositAmount);

        vm.expectRevert("Vault: newShare cannot be zero");
        vaultManager.deposit(underlyingToken, aaveVault, depositAmount, true);

        vm.stopPrank();
    }

    function testExcessiveWithdraw() public {
        vm.startPrank(owner);

        vaultManager.addVault(aaveVault);
        uint256 depositAmount = 100 * 10 ** 18;

        underlyingToken.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(underlyingToken, aaveVault, depositAmount, true);

        uint256 excessiveWithdrawAmount = 200 * 10 ** 18;
        uint256 sharesWithdrawAmount = aaveVault.underlyingToShares(excessiveWithdrawAmount);

        IVault[] memory vaults = new IVault[](1);
        vaults[0] = aaveVault;

        uint256[] memory sharesToWithdraw = new uint256[](1);
        sharesToWithdraw[0] = sharesWithdrawAmount;

        vm.expectRevert("VaultManager: insufficient shares");
        vaultManager.queueWithdrawals(vaults, sharesToWithdraw, owner);

        vm.stopPrank();
    }

    function testMultipleUsersDepositAndWithdraw() public {
        address userA = address(0x1);
        address userB = address(0x2);
        uint256 depositA = 100 * 10 ** 18;
        uint256 depositB = 200 * 10 ** 18;

        // User A deposits
        vm.startPrank(owner);
        vaultManager.addVault(aaveVault);
        underlyingToken.transfer(userA, depositA);
        underlyingToken.transfer(userB, depositB);

        vm.stopPrank();

        vm.startPrank(userA);
        underlyingToken.approve(address(vaultManager), depositA);
        vaultManager.deposit(underlyingToken, aaveVault, depositA, true);
        vm.stopPrank();

        vm.startPrank(userB);
        underlyingToken.approve(address(vaultManager), depositB);
        vaultManager.deposit(underlyingToken, aaveVault, depositB, true);
        vm.stopPrank();

        uint256 totalShares = aaveVault.totalShares();
        assertEq(totalShares, depositA + depositB, "Total shares mismatch");

        uint256 withdrawAmountA = 50 * 10 ** 18;
        uint256 sharesWithdrawAmountA = aaveVault.underlyingToShares(withdrawAmountA);

        vm.startPrank(userA);
        IVault[] memory vaults = new IVault[](1);
        vaults[0] = aaveVault;

        uint256[] memory sharesToWithdrawA = new uint256[](1);
        sharesToWithdrawA[0] = sharesWithdrawAmountA;

        uint256 withdrawLockBlock = vaultManager.withdrawLockBlock();
        vm.roll(block.number + withdrawLockBlock + 1);

        bytes32 withdrawalIdA = vaultManager.queueWithdrawals(vaults, sharesToWithdrawA, userA);

        bytes32[] memory withdrawalIdsA = new bytes32[](1);
        withdrawalIdsA[0] = withdrawalIdA;

        vm.roll(block.number + withdrawLockBlock + 2);

        vaultManager.completeWithdrawals(withdrawalIdsA);

        uint256 finalBalanceA = underlyingToken.balanceOf(userA);
        assertEq(finalBalanceA, withdrawAmountA, "User A withdrawal mismatch");
        vm.stopPrank();
    }

    function testYieldAccumulationOnFork() public {
        vm.startPrank(owner);

        vaultManager.addVault(aaveVault);
        uint256 depositAmount = 100 * 10 ** 18;

        underlyingToken.approve(address(vaultManager), depositAmount);
        vaultManager.deposit(underlyingToken, aaveVault, depositAmount, true);

        uint256 tolerance = 1;
        uint256 initialATokenBalance = aToken.balanceOf(address(aaveVault));
        assertApproxEqAbs(initialATokenBalance, depositAmount, tolerance, "Initial aToken balance mismatch");

        uint256 oneYearInSeconds = 365 days;
        vm.warp(block.timestamp + oneYearInSeconds);
        vm.roll(block.number + 1000);

        uint256 updatedATokenBalance = aToken.balanceOf(address(aaveVault));
        assertGt(updatedATokenBalance, initialATokenBalance, "No yield generated");

        uint256 totalAssets = aaveVault.totalAssets();
        assertEq(totalAssets, updatedATokenBalance, "Total assets mismatch after yield");

        vm.stopPrank();
    }
}

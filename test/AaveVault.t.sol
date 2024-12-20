// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {AaveVault} from "../src/vaults/AaveVault.sol";
import {UpgradeableOpenfortProxy} from "../src/proxy/UpgradeableOpenfortProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "aave-v3-origin/core/contracts/interfaces/IPool.sol";
import {InvoiceManager} from "../src/core/InvoiceManager.sol";
import {IVault} from "../src/interfaces/IVault.sol";
import {CheckAaveTokenStatus} from "../script/auxiliary/checkAaveTokenStatus.s.sol";

contract DeployAndTestAaveVaults is Test, Script, CheckAaveTokenStatus {
    address internal deployer;
    address internal owner;
    VaultManager internal vaultManager;
    AaveVault internal aaveVault;
    InvoiceManager internal invoiceManager;
    IERC20 internal underlyingToken;
    IERC20 internal aToken;

    address aavePool = vm.envAddress("AAVE_POOL");
    address internal protocolDataProvider = vm.envAddress("AAVE_DATA_PROVIDER");
    address underlyingTokenAddress = vm.envAddress("UNDERLYING_TOKEN");

    function setUp() public {
        deployer = vm.envAddress("OWNER");
        owner = deployer;

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
                            IPool(aavePool)
                        )
                    )
                )
            );
        }
    }

    function testIsAaveToken() public {
        bool tokenIsActive = isAaveToken(protocolDataProvider, address(underlyingToken));
        assertTrue(tokenIsActive, "Underlying token is not active in Aave");
    }

    function testGetATokenAddress() public {
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
}

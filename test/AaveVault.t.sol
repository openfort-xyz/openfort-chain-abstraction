// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {AaveVault} from "../src/vaults/AaveVault.sol";
import {UpgradeableOpenfortProxy} from "../src/proxy/UpgradeableOpenfortProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IL2Pool} from "aave-v3-origin/core/contracts/interfaces/IL2Pool.sol";
import {L2Encoder} from "aave-v3-origin/core/contracts/misc/L2Encoder.sol";
import {InvoiceManager} from "../src/core/InvoiceManager.sol";
import {IVault} from "../src/interfaces/IVault.sol";

contract DeployAndTestSepoliaVaults is Test, Script {
    address internal deployer;
    address internal owner;
    VaultManager internal vaultManager;
    AaveVault internal aaveVault;
    InvoiceManager internal invoiceManager;
    IERC20 internal dai;
    IERC20 internal aDai;

    address underlyingToken = vm.envAddress("UNDERLYING_TOKEN");
    address aToken = vm.envAddress("A_TOKEN");

    address aavePool = vm.envAddress("AAVE_POOL");

    function setUp() public {
        // Set up accounts
        deployer = vm.envAddress("OWNER");
        owner = deployer;

        // Set up the DAI token interface
        dai = IERC20(underlyingToken);
        aDai = IERC20(aToken);

        // Deploy InvoiceManager
        invoiceManager = InvoiceManager(
            payable(
                new UpgradeableOpenfortProxy(address(new InvoiceManager()), "")
            )
        );
        console.log("InvoiceManager Address:", address(invoiceManager));

        // Deploy VaultManager
        vaultManager = VaultManager(
            payable(
                new UpgradeableOpenfortProxy(
                    address(new VaultManager()),
                    abi.encodeWithSelector(
                        VaultManager.initialize.selector,
                        owner,
                        address(invoiceManager),
                        10 // Withdrawal lock block
                    )
                )
            )
        );
        console.log("VaultManager Address:", address(vaultManager));

        // Deploy AaveVault
        aaveVault = AaveVault(
            address(
                new UpgradeableOpenfortProxy(
                    address(new AaveVault()),
                    abi.encodeWithSelector(
                        AaveVault.initialize.selector,
                        address(vaultManager),
                        dai,
                        aDai,
                        aavePool
                    )
                )
            )
        );
        console.log("AaveVault Address:", address(aaveVault));
    }

    function testDeployAndInteraction() public {
        vm.startPrank(owner);

        uint256 initialDeployerDAIBalance = dai.balanceOf(deployer);
        console.log("Initial Deployer DAI Balance:", initialDeployerDAIBalance);

        // Register the AaveVault
        vaultManager.addVault(aaveVault);
        console.log("AaveVault registered in VaultManager");

        // Simulate deposit
        uint256 depositAmount = 100 * 10 ** 18; // 100 DAI
        dai.approve(address(vaultManager), depositAmount);
        console.log(
            "Approved VaultManager to spend DAI:",
            dai.allowance(owner, address(vaultManager))
        );

        vaultManager.deposit(dai, aaveVault, depositAmount, true);
        console.log("Deposited 100 DAI to AaveVault");

        // Check post-deposit balances
        uint256 postDepositVaultaTokenBalance = aDai.balanceOf(
            address(aaveVault)
        );
        uint256 userShares = vaultManager.vaultShares(owner, aaveVault);
        console.log(
            "Post-Deposit Vault aToken Balance:",
            postDepositVaultaTokenBalance
        );
        console.log("Post-Deposit user Shares:", userShares);

        // Simulate withdrawal
        uint256 withdrawAmount = 100 * 10 ** 18; // Withdraw 100 DAI
        uint256 sharesWithdrawAmount = aaveVault.underlyingToShares(
            withdrawAmount
        );

        IVault[] memory vaults = new IVault[](1); // Array with one element
        vaults[0] = aaveVault;

        uint256[] memory sharesToWithdraw = new uint256[](1);
        sharesToWithdraw[0] = sharesWithdrawAmount;

        // Advance blocks to pass the lock period
        uint256 withdrawLockBlock = vaultManager.withdrawLockBlock();
        vm.roll(block.number + withdrawLockBlock + 1000);

        bytes32 withdrawalId = vaultManager.queueWithdrawals(
            vaults,
            sharesToWithdraw,
            deployer
        );
        console.log("Withdrawal ID:");
        console.logBytes32(bytes32(withdrawalId));

        // Complete the withdrawal
        bytes32[] memory withdrawalIds = new bytes32[](1);
        withdrawalIds[0] = withdrawalId;
        console.log("check");

        // Advance time for yield accrual
        uint256 oneYearInSeconds = 365 days;
        vm.warp(block.timestamp + oneYearInSeconds);
        console.log("Time advanced by 1 year.");
        vm.roll(block.number + 1000);

        vaultManager.completeWithdrawals(withdrawalIds);
        console.log("Completed withdrawal");

        // Post-withdrawal balance check
        uint256 finalDeployerDAIBalance = dai.balanceOf(deployer);
        console.log("Final Deployer DAI Balance:", finalDeployerDAIBalance);

        // Calculate and log yield
        uint256 yieldEarned = finalDeployerDAIBalance -
            initialDeployerDAIBalance;
        console.log("Yield Earned:", yieldEarned);

        vm.stopPrank();
    }
}

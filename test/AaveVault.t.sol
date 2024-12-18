// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {AaveVault} from "../src/vaults/AaveVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IL2Pool} from "aave-v3-origin/core/contracts/interfaces/IL2Pool.sol";
import {L2Encoder} from "aave-v3-origin/core/contracts/misc/L2Encoder.sol";
import {InvoiceManager} from "../src/core/InvoiceManager.sol";

contract TestSepoliaDeployment is Test, Script {
    address internal deployer;
    address internal owner;
    VaultManager internal vaultManager;
    AaveVault internal aaveVault;
    IERC20 internal dai;
    InvoiceManager internal invoiceManager =
        InvoiceManager(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951);

    IL2Pool internal aavePool =
        IL2Pool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951); // Sepolia Pool Address
    address internal protocolDataProvider =
        0x3e9708d80f7B3e43118013075F7e95CE3AB31F31; // Sepolia Protocol Data Provider Address
    L2Encoder internal l2Encoder =
        L2Encoder(0x3e9708d80f7B3e43118013075F7e95CE3AB31F31); // Sepolia L2 Encoder Address
    address internal daiAddress = 0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357; // Sepolia DAI Address

    uint256 deployerPrivKey = vm.envUint("PK_DEPLOYER");

    function setUp() public {
        // Set up accounts
        deployer = vm.addr(deployerPrivKey);
        owner = deployer;

        // Set up the DAI token interface
        dai = IERC20(daiAddress);
    }

    function testDeployAndInteraction() public {
        vm.startBroadcast(deployerPrivKey);

        // Deploy VaultManager
        vaultManager = new VaultManager();
        vaultManager.initialize(owner, invoiceManager, 100); // Dummy parameters for testing
        console.log("VaultManager deployed at:", address(vaultManager));

        // Deploy AaveVault
        aaveVault = new AaveVault();
        aaveVault.initialize(vaultManager, dai, aavePool, l2Encoder);
        console.log("AaveVault deployed at:", address(aaveVault));

        // Register the vault in VaultManager
        vaultManager.addVault(aaveVault);
        console.log("AaveVault registered in VaultManager");

        // Check initial balances
        uint256 initialVaultBalance = dai.balanceOf(address(aaveVault));
        uint256 initialDeployerBalance = dai.balanceOf(deployer);
        console.log("Initial Vault Balance:", initialVaultBalance);
        console.log("Initial Deployer Balance:", initialDeployerBalance);

        // Simulate a deposit of 1000 DAI
        uint256 depositAmount = 1000 * 10 ** 18; // 1000 DAI
        vm.startPrank(deployer); // Set deployer as the transaction sender
        dai.approve(address(vaultManager), depositAmount);
        console.log("Approved VaultManager to spend DAI");

        vaultManager.deposit(dai, aaveVault, depositAmount, false);
        console.log("Deposited 1000 DAI to AaveVault");

        // Check balances after deposit
        uint256 postDepositVaultBalance = dai.balanceOf(address(aaveVault));
        uint256 postDepositDeployerBalance = dai.balanceOf(deployer);
        console.log("Post-Deposit Vault Balance:", postDepositVaultBalance);
        console.log(
            "Post-Deposit Deployer Balance:",
            postDepositDeployerBalance
        );

        // Simulate a withdrawal of 100 DAI
        uint256 withdrawAmount = 100 * 10 ** 18; // 100 DAI
        aaveVault.withdraw(dai, withdrawAmount, owner);
        console.log("Withdrew 100 DAI from AaveVault");

        // Check balances after withdrawal
        uint256 postWithdrawVaultBalance = dai.balanceOf(address(aaveVault));
        uint256 postWithdrawDeployerBalance = dai.balanceOf(deployer);
        console.log("Post-Withdrawal Vault Balance:", postWithdrawVaultBalance);
        console.log(
            "Post-Withdrawal Deployer Balance:",
            postWithdrawDeployerBalance
        );

        vm.stopBroadcast();
    }
}

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

    uint256 deployerPrivKey = vm.envUint("PK_DEPLOYER");

    address underlyingToken = vm.envAddress("UNDERLYING_TOKEN");
    address aToken = vm.envAddress("A_TOKEN");

    address aavePool = vm.envAddress("AAVE_POOL");

    // address dataProvider = vm.envAddress("AAVE_DATA_PROVIDER");

    function setUp() public {
        vm.startBroadcast(deployerPrivKey);
        // Set up accounts
        deployer = vm.addr(deployerPrivKey);
        // deployer = vm.envAddress("OWNER");
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
                        aavePool
                    )
                )
            )
        );
        console.log("AaveVault Address:", address(aaveVault));
        console.log("EOA DAI Balance in fork:", dai.balanceOf(deployer));
    }

    function testDeployAndInteraction() public {
        // vm.startBroadcast(deployerPrivKey);
        // vm.prank(owner);
        // vm.startPrank(owner);
        // Register the AaveVault in VaultManager
        vaultManager.addVault(aaveVault);
        console.log("AaveVault registered in VaultManager");
        console.log(" ");

        // Simulate interaction: Deposit 1000 DAI
        uint256 depositAmount = 100 * 10 ** 18; // 100 DAI
        dai.approve(address(vaultManager), depositAmount);
        uint256 allowance = dai.allowance(owner, address(vaultManager));
        console.log("Approved VaultManager to spend DAI", allowance);

        vaultManager.deposit(dai, aaveVault, depositAmount, true);
        console.log("Deposited 100 DAI to AaveVault");

        // Check post-deposit balances
        uint256 postDepositDeployerBalance = dai.balanceOf(deployer);
        uint256 userShares = vaultManager.vaultShares(owner, aaveVault);
        // vm.roll(block.number + 2); // Advance one block
        uint256 postDepositVaultaTokenBalance = aDai.balanceOf(
            address(aaveVault)
        );
        uint256 postDepositVaultBalance = dai.balanceOf(address(aaveVault));
        console.log(
            "Post-Deposit Vault aToken Balance:",
            postDepositVaultaTokenBalance
        );
        console.log("Post-Deposit Vault Balance:", postDepositVaultBalance);
        console.log("Post-Deposit user Shares:", userShares);
        console.log(
            "Post-Deposit Deployer Balance:",
            postDepositDeployerBalance
        );

        // Simulate withdrawal of 10 DAI
        uint256 withdrawAmount = 10 * 10 ** 18;
        uint256 sharesWithdrawAmount = aaveVault.underlyingToShares(
            withdrawAmount
        );

        // Queue the withdrawal
        IVault[] memory vaults = new IVault[](1); // Array with one element
        vaults[0] = aaveVault;

        uint256[] memory sharesToWithdraw = new uint256[](1);
        sharesToWithdraw[0] = sharesWithdrawAmount;

        bytes32 withdrawalId = vaultManager.queueWithdrawals(
            vaults,
            sharesToWithdraw,
            deployer
        );
        console.log("Withdrawal ID:");
        console.logBytes32(bytes32(withdrawalId));

        // Advance blocks to pass the lock period
        uint256 withdrawLockBlock = vaultManager.withdrawLockBlock();
        // vm.roll(block.number + withdrawLockBlock + 1);

        // Complete the withdrawal
        bytes32[] memory withdrawalIds;
        withdrawalIds[0] = withdrawalId;

        vaultManager.completeWithdrawals(withdrawalIds);
        console.log("Completed withdrawal");

        // Check post-withdrawal balances
        uint256 postWithdrawVaultBalance = dai.balanceOf(address(aaveVault));
        uint256 postWithdrawDeployerBalance = dai.balanceOf(deployer);
        uint256 postWithdrawDeployerADaiBalance = aDai.balanceOf(deployer);
        console.log("Post-Withdrawal Vault Balance:", postWithdrawVaultBalance);
        console.log(
            "Post-Withdrawal Deployer Balance:",
            postWithdrawDeployerBalance
        );
        console.log(
            "Post-Withdrawal Deployer aDai Balance:",
            postWithdrawDeployerADaiBalance
        );

        vm.stopBroadcast();
    }
}

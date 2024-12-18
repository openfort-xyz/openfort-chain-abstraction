// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {AaveVault} from "../src/vaults/AaveVault.sol";
import {UpgradeableOpenfortProxy} from "../src/proxy/UpgradeableOpenfortProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IL2Pool} from "aave-v3-origin/core/contracts/interfaces/IL2Pool.sol";
import {AaveProtocolDataProvider} from "aave-v3-origin/core/contracts/misc/AaveProtocolDataProvider.sol";
import {InvoiceManager} from "../src/core/InvoiceManager.sol";

contract DeploySepoliaVaults is Script {
    function run() public {
        uint256 deployerPrivKey = vm.envUint("PK_DEPLOYER");
        address owner = vm.envAddress("OWNER");
        address token = vm.envAddress("TOKEN");
        address aavePool = vm.envAddress("AAVE_POOL");
        address dataProvider = vm.envAddress("AAVE_DATA_PROVIDER");
        bytes32 versionSalt = vm.envBytes32("VERSION_SALT");

        vm.startBroadcast(deployerPrivKey);

        // Deploy InvoiceManager
        InvoiceManager invoiceManager = new InvoiceManager();
        console.log("InvoiceManager Address:", address(invoiceManager));

        // Deploy VaultManager
        VaultManager vaultManager = VaultManager(
            payable(
                new UpgradeableOpenfortProxy{salt: versionSalt}(
                    address(new VaultManager()),
                    abi.encodeWithSelector(
                        VaultManager.initialize.selector,
                        owner,
                        address(invoiceManager), // Pass the real InvoiceManager address
                        100
                    )
                )
            )
        );
        console.log("VaultManager Address:", address(vaultManager));

        // Deploy AaveVault
        AaveVault aaveVault = AaveVault(
            payable(
                new UpgradeableOpenfortProxy{salt: versionSalt}(
                    address(new AaveVault()),
                    abi.encodeWithSelector(
                        AaveVault.initialize.selector,
                        address(vaultManager),
                        IERC20(token),
                        IL2Pool(aavePool),
                        AaveProtocolDataProvider(dataProvider)
                    )
                )
            )
        );
        console.log("AaveVault Address:", address(aaveVault));

        // Add AaveVault to VaultManager
        vaultManager.addVault(aaveVault);

        vm.stopBroadcast();
    }
}

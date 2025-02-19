// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../src/interfaces/IInvoiceManager.sol";
import {IVaultManager} from "../src/interfaces/IVaultManager.sol";
import {Script, console} from "forge-std/Script.sol";

import {InvoiceManager} from "../src/core/InvoiceManager.sol";
import {CABPaymaster} from "../src/paymasters/CABPaymaster.sol";
import {CABPaymasterFactory} from "../src/paymasters/CABPaymasterFactory.sol";
import {UpgradeableOpenfortProxy} from "../src/proxy/UpgradeableOpenfortProxy.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {CheckOrDeployEntryPoint} from "./auxiliary/checkOrDeployEntrypoint.sol";
import {DeployPolymerPaymasterVerifier} from "./deployPolymerPaymasterVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployChainAbstractionSetup is Script, CheckOrDeployEntryPoint, DeployPolymerPaymasterVerifier {
    uint256 internal deployerPrivKey = vm.envUint("PK_DEPLOYER");
    uint256 internal withdrawLockBlock = vm.envUint("WITHDRAW_LOCK_BLOCK");
    address internal deployer = vm.addr(deployerPrivKey);
    address internal owner = vm.envAddress("OWNER");
    address internal paymasterFactoryOwner = vm.envAddress("PAYMASTER_FACTORY_OWNER");
    address internal verifyingSigner = vm.envAddress("VERIFYING_SIGNER");
    bytes32 internal versionSalt = vm.envBytes32("VERSION_SALT");

    function run(address[] calldata tokens) public {
        if (tokens.length == 0) revert("No tokens provided");

        console.log("Deployer Address", deployer);
        console.log("Owner Address", owner);
        console.log("Verifying Signer Address", verifyingSigner);

        vm.startBroadcast(deployerPrivKey);

        InvoiceManager invoiceManagerImpl = new InvoiceManager{salt: versionSalt}();
        console.log("InvoiceManagerImpl Address", address(invoiceManagerImpl));

        InvoiceManager invoiceManager =
            InvoiceManager(payable(new UpgradeableOpenfortProxy{salt: versionSalt}(address(invoiceManagerImpl), "")));
        console.log("InvoiceManager Address", address(invoiceManager));
        VaultManager vaultManager = VaultManager(
            payable(
                new UpgradeableOpenfortProxy{salt: versionSalt}(
                    address(new VaultManager()),
                    abi.encodeWithSelector(
                        VaultManager.initialize.selector, owner, IInvoiceManager(address(invoiceManager)), withdrawLockBlock
                    )
                )
            )
        );

        console.log("VaultManager Address", address(vaultManager));
        invoiceManager.initialize(owner, IVaultManager(address(vaultManager)));

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token.code.length == 0) revert("Token not deployed");
            BaseVault vault = BaseVault(
                payable(
                    new UpgradeableOpenfortProxy{salt: versionSalt}(
                        // Note: avoid create2 collision by using a different salt for each vault
                        address(new BaseVault{salt: versionSalt << i}()),
                        abi.encodeWithSelector(BaseVault.initialize.selector, IVaultManager(address(vaultManager)), IERC20(token))
                    )
                )
            );
            console.log("Vault Address", address(vault));
            vaultManager.addVault(vault);
        }

        checkOrDeployEntryPoint();

        CABPaymasterFactory paymasterFactory =
            new CABPaymasterFactory{salt: versionSalt}(paymasterFactoryOwner, address(invoiceManager), verifyingSigner);

        address paymaster = paymasterFactory.createCABPaymaster(owner, versionSalt, tokens);

        console.log("Paymaster Address", address(paymaster));
        deployPaymasterVerifier(address(invoiceManager), owner, versionSalt);
        vm.stopBroadcast();
    }
}

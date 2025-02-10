// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {IEntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IInvoiceManager} from "../src/interfaces/IInvoiceManager.sol";
import {IVaultManager} from "../src/interfaces/IVaultManager.sol";
import {CheckOrDeployEntryPoint} from "./auxiliary/checkOrDeployEntrypoint.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableOpenfortProxy} from "../src/proxy/UpgradeableOpenfortProxy.sol";
import {BaseVault} from "../src/vaults/BaseVault.sol";
import {VaultManager} from "../src/vaults/VaultManager.sol";
import {CABPaymaster} from "../src/paymasters/CABPaymaster.sol";
import {InvoiceManager} from "../src/core/InvoiceManager.sol";

import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";

import {LiquidityManager} from "../src/liquidity/LiquidityManager.sol";
import {ILiquidityManager} from "../src/interfaces/ILiquidityManager.sol";
import {MiniFactory} from "../src/exchange/MiniSwap/MiniFactory.sol";
import {MiniRouter} from "../src/exchange/MiniSwap/MiniRouter.sol";

// forge script script/deployChainAbstractionSetup.s.sol:DeployChainAbstractionSetup "[0xusdc, 0xusdt]" --sig "run(address[])" --via-ir --rpc-url=127.0.0.1:854

contract DeployChainAbstractionSetup is Script, CheckOrDeployEntryPoint {
    uint256 internal deployerPrivKey = vm.envUint("PK_DEPLOYER");
    uint256 internal withdrawLockBlock = vm.envUint("WITHDRAW_LOCK_BLOCK");
    address internal deployer = vm.addr(deployerPrivKey);
    address internal crossL2Prover = vm.envAddress("CROSS_L2_PROVER");
    address internal owner = vm.envAddress("OWNER");
    address internal verifyingSigner = vm.envAddress("VERIFYING_SIGNER");
    bytes32 internal versionSalt = vm.envBytes32("VERSION_SALT");

    function run(address[] calldata tokens) public {
        if (tokens.length == 0) {
            revert("No tokens provided");
        }

        console.log("Deployer Address", deployer);
        console.log("Owner Address", owner);
        console.log("Verifying Signer Address", verifyingSigner);

        vm.startBroadcast(deployerPrivKey);

        InvoiceManager invoiceManagerImpl = new InvoiceManager();
        console.log("InvoiceManagerImpl Address", address(invoiceManagerImpl));

        InvoiceManager invoiceManager =
            InvoiceManager(payable(new UpgradeableOpenfortProxy{salt: versionSalt}(address(invoiceManagerImpl), "")));
        console.log("InvoiceManager Address", address(invoiceManager));
        VaultManager vaultManager = VaultManager(
            payable(
                new UpgradeableOpenfortProxy{salt: versionSalt}(
                    address(new VaultManager()),
                    abi.encodeWithSelector(
                        VaultManager.initialize.selector,
                        owner,
                        IInvoiceManager(address(invoiceManager)),
                        withdrawLockBlock
                    )
                )
            )
        );

        console.log("VaultManager Address", address(vaultManager));
        invoiceManager.initialize(owner, IVaultManager(address(vaultManager)));

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token.code.length == 0) {
                revert("Token not deployed");
            }
            BaseVault vault = BaseVault(
                payable(
                    new UpgradeableOpenfortProxy{salt: versionSalt}(
                        address(new BaseVault()),
                        abi.encodeWithSelector(
                            BaseVault.initialize.selector, IVaultManager(address(vaultManager)), IERC20(token)
                        )
                    )
                )
            );
            console.log("Vault Address", address(vault));
            vaultManager.addVault(vault);
        }

        IEntryPoint entryPoint = checkOrDeployEntryPoint();
        MiniFactory miniFactory = new MiniFactory();
        MiniRouter miniRouter = new MiniRouter(address(miniFactory));
        LiquidityManager liquidityManager = new LiquidityManager(address(miniRouter), address(miniFactory));

        CABPaymaster paymaster = new CABPaymaster{salt: versionSalt}(
            entryPoint, IInvoiceManager(address(invoiceManager)), ICrossL2Prover(crossL2Prover), ILiquidityManager(address(liquidityManager)), verifyingSigner, owner
        );

        console.log("Paymaster Address", address(paymaster));
        vm.stopBroadcast();
    }
}

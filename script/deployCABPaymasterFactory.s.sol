// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CABPaymasterFactory} from "../contracts/paymasters/CABPaymasterFactory.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployCABPaymasterFactory is Script {
    function run() public {
        bytes32 versionSalt = vm.envBytes32("VERSION_SALT");
        address invoiceManager = vm.envAddress("INVOICE_MANAGER");
        address verifyingSigner = vm.envAddress("VERIFYING_SIGNER");
        address owner = vm.envAddress("OWNER");
        vm.startBroadcast();
        address cabPaymasterFactory = address(new CABPaymasterFactory{salt: versionSalt}(owner, invoiceManager, verifyingSigner));
        console.log("CABPaymasterFactory deployed at", cabPaymasterFactory);
        vm.stopBroadcast();
    }
}

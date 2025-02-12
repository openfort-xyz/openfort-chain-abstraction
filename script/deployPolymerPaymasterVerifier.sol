// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ICrossL2ProverV2, PolymerPaymasterVerifierV2} from "../src/paymasters/PolymerPaymasterVerifierV2.sol";
import {PolymerPaymasterVerifier} from "../src/paymasters/PolymerPaymasterVerifier.sol";
import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";
import {IInvoiceManager} from "../src/interfaces/IInvoiceManager.sol";

contract DeployPolymerPaymasterVerifier is Script {
    address internal crossL2Prover = vm.envAddress("CROSS_L2_PROVER");

    function deployPaymasterVerifier(address _invoiceManager, address _owner, bytes32 _versionSalt) public {
        vm.startBroadcast();
        if (crossL2Prover == 0xb8AcB3FE3117A67b665Bc787c977623612f8a461) {
            PolymerPaymasterVerifier polymerPaymasterVerifier = new PolymerPaymasterVerifier{salt: _versionSalt}(
                IInvoiceManager(_invoiceManager), ICrossL2Prover(crossL2Prover), _owner
            );
            console.log("PolymerPaymasterVerifierV1 deployed at", address(polymerPaymasterVerifier));
        } else {
            PolymerPaymasterVerifierV2 polymerPaymasterVerifierV2 = new PolymerPaymasterVerifierV2{salt: _versionSalt}(
                IInvoiceManager(_invoiceManager), ICrossL2ProverV2(crossL2Prover), _owner
            );
            console.log("PolymerPaymasterVerifierV2 deployed at", address(polymerPaymasterVerifierV2));
        }
        vm.stopBroadcast();
    }
}

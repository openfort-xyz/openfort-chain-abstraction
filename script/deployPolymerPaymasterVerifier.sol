// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICrossL2ProverV2} from "../contracts/interfaces/ICrossL2ProverV2.sol";
import {IInvoiceManager} from "../contracts/interfaces/IInvoiceManager.sol";
import {PolymerPaymasterVerifierV1} from "../contracts/paymasters/verifiers/PolymerPaymasterVerifierV1.sol";
import {PolymerPaymasterVerifierV2} from "../contracts/paymasters/verifiers/PolymerPaymasterVerifierV2.sol";
import {ICrossL2Prover} from "@vibc-core-smart-contracts/contracts/interfaces/ICrossL2Prover.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployPolymerPaymasterVerifier is Script {
    address internal crossL2Prover = vm.envAddress("CROSS_L2_PROVER");

    function deployPolymerPaymasterVerifier(address _invoiceManager, address _owner, bytes32 _versionSalt) public {
        if (crossL2Prover == 0xb8AcB3FE3117A67b665Bc787c977623612f8a461) {
            PolymerPaymasterVerifierV1 polymerPaymasterVerifier = new PolymerPaymasterVerifierV1{salt: _versionSalt}(
                IInvoiceManager(_invoiceManager), ICrossL2Prover(crossL2Prover), _owner
            );
            console.log("PolymerPaymasterVerifierV1 deployed at", address(polymerPaymasterVerifier));
        } else {
            PolymerPaymasterVerifierV2 polymerPaymasterVerifierV2 = new PolymerPaymasterVerifierV2{salt: _versionSalt}(
                IInvoiceManager(_invoiceManager), ICrossL2ProverV2(crossL2Prover), _owner
            );
            console.log("PolymerPaymasterVerifierV2 deployed at", address(polymerPaymasterVerifierV2));
        }
    }
}

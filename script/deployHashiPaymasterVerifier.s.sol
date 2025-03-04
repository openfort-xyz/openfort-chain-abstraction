// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../contracts/interfaces/IInvoiceManager.sol";
import {HashiPaymasterVerifier} from "../contracts/paymasters/verifiers/HashiPaymasterVerifier.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployHashiPaymasterVerifier is Script {
    address internal shoyuBashi = vm.envAddress("SHOYU_BASHI");

    function deployHashiPaymasterVerifier(address _invoiceManager, address _owner, bytes32 _versionSalt)
        public
        returns (HashiPaymasterVerifier)
    {
        HashiPaymasterVerifier hashiPaymasterVerifier =
            new HashiPaymasterVerifier{salt: _versionSalt}(IInvoiceManager(_invoiceManager), shoyuBashi, _owner);
        console.log("HashiPaymasterVerifier deployed at ", address(hashiPaymasterVerifier));
        return hashiPaymasterVerifier;
    }
}

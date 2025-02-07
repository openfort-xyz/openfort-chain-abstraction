import {Script, console} from "forge-std/Script.sol";
import {CABPaymasterFactory} from "../src/paymasters/CABPaymasterFactory.sol";

contract DeployCABPaymasterFactory is Script {
    function run() public {
        bytes32 versionSalt = vm.envBytes32("VERSION_SALT");
        address invoiceManager = vm.envAddress("INVOICE_MANAGER");
        address crossL2Prover = vm.envAddress("CROSS_L2_PROVER");
        address verifyingSigner = vm.envAddress("VERIFYING_SIGNER");
        address owner = vm.envAddress("OWNER");
        vm.startBroadcast();
        address cabPaymasterFactory =
            address(new CABPaymasterFactory{salt: versionSalt}(owner, invoiceManager, crossL2Prover, verifyingSigner));
        console.log("CABPaymasterFactory deployed at", cabPaymasterFactory);
        vm.stopBroadcast();
    }
}

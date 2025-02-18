// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {EntryPoint, IEntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {Script} from "forge-std/Script.sol";

import {console} from "forge-std/console.sol";

contract CheckOrDeployEntryPoint is Script {
    uint256 private ANVIL_CHAINID = 31337;

    function checkOrDeployEntryPoint() public returns (IEntryPoint entryPoint) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        // If we are in a fork
        if (vm.envAddress("ENTRY_POINT_ADDRESS").code.length > 0) {
            entryPoint = IEntryPoint(payable(vm.envAddress("ENTRY_POINT_ADDRESS")));
        }
        // If not a fork, deploy entryPoint (at correct address)
        else if (chainId == ANVIL_CHAINID) {
            EntryPoint entryPointAux = new EntryPoint();
            bytes memory code = address(entryPointAux).code;
            address targetAddr = address(vm.envAddress("ENTRY_POINT_ADDRESS"));
            vm.etch(targetAddr, code);
            entryPoint = IEntryPoint(payable(targetAddr));
            require(
                IERC165(address(entryPoint)).supportsInterface(type(IEntryPoint).interfaceId), "IEntryPoint interface mismatch"
            );
            console.log("EntryPoint deployed at", address(entryPoint));
        } else {
            revert("No EntryPoint in this chain");
        }
    }
}

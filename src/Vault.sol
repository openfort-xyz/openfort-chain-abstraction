// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.19;


import {ETH} from "./Utils.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-5.0.2/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Vault {
    function deposit() external payable {}
    function withdraw() external {}
}

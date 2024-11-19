// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.20;


import {ETH} from "./Utils.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin-5.1.0/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-5.1.0/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin-5.1.0/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";



contract Vault is ReentrancyGuardUpgradeable, OwnableUpgradeable, EIP712Upgradeable {

    uint256 public lockDuration;

    struct Deposit {
        address owner;
        address token;
        uint256 amount;
        uint256 lockUntil;
    }

    constructor() {
        _disableInitializers();
    }


    function initialize(uint256 _lockDuration, address _owner) public initializer {
        __Ownable_init(_owner);
        __EIP712_init("OpenfortChainAbstraction", "1");
        lockDuration = _lockDuration;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function deposit() external payable {}
    function withdraw() external {}
}

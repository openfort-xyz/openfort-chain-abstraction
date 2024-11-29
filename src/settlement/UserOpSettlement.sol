// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract UserOpSettlement is UUPSUpgradeable, OwnableUpgradeable {
    address public paymaster;

    /// @notice Mapping: userOpHash => SponsorToken[] to store the sponsor tokens.
    mapping(bytes32 => IPaymasterVerifier.SponsorToken[]) public userOpWithSponsorTokens;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, address _paymaster) public initializer {
        __Ownable_init(_owner);
        paymaster = _paymaster;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyPaymaster() {
        require(msg.sender == paymaster, "Only paymaster can call this function");
        _;
    }

    /// @notice Add the sponsor tokens to the userOpHash.
    function push(bytes32 userOpHash, IPaymasterVerifier.SponsorToken[] calldata sponsorTokens) public onlyPaymaster {
        userOpWithSponsorTokens[userOpHash] = sponsorTokens;
    }

    // function settle(bytes32[] calldata userOpHashes) public onlyPaymasterVerifier {
    //     // TODO: use socket to call invoice manager for refund
    //     // outbound repay
    //     // TODO: make sure the refund call is successful before deleting the userOpWithSponsorTokens
    //     for (uint256 i = 0; i < userOpHashes.length; i++) {
    //         delete userOpWithSponsorTokens[userOpHashes[i]];
    //     }
    // }
}

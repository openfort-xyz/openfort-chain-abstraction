// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IPaymasterVerifier} from "../interfaces/IPaymasterVerifier.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ISocket} from "@socket/interfaces/ISocket.sol";

contract UserOpSettlement is UUPSUpgradeable, OwnableUpgradeable {
    ISocket public immutable socket;
    uint256 public minMsgGasLimit;
    address public paymaster;

    error NoSocketFee();
    error NotSocket();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Mapping: userOpHash => SponsorToken[] to store the sponsor tokens.
    mapping(bytes32 => IPaymasterVerifier.SponsorToken[]) public userOpWithSponsorTokens;

    constructor(address _socket) {
        socket = ISocket(_socket);
        _disableInitializers();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ADMIN FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    modifier onlyPaymaster() {
        require(msg.sender == paymaster, "Only paymaster can call this function");
        _;
    }

    function initialize(address _owner, address _paymaster, uint256 _minMsgGasLimit) public initializer {
        __Ownable_init(_owner);
        paymaster = _paymaster;

        // gas limit for the outbound call
        minMsgGasLimit = _minMsgGasLimit;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      PAYMASTER FUNCTIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           SOCKET                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function connect(uint32 remoteChainSlug, address remotePlug, address switchboard) public onlyOwner {
        socket.connect(remoteChainSlug, remotePlug, switchboard, switchboard);
    }

    function _outbound(uint32 targetChain, bytes32 executionParams, bytes32 transmissionParams, bytes memory payload)
        private
    {
        uint256 fee = socket.getMinFees(
            minMsgGasLimit, uint256(payload.length), executionParams, transmissionParams, targetChain, address(this)
        );

        // This UserOpSettlement contract must have enouh native token
        // to pay for the outbound call !!!!

        if (address(this).balance < fee) revert NoSocketFee();
        socket.outbound{value: fee}(targetChain, minMsgGasLimit, executionParams, transmissionParams, payload);
    }
}

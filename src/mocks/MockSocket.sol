// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {ISocket} from "@socket/interfaces/ISocket.sol";
import {IPlug} from "@socket/interfaces/IPlug.sol";
import {ITransmitManager} from "@socket/interfaces/ITransmitManager.sol";
import {IExecutionManager} from "@socket/interfaces/IExecutionManager.sol";

import {console} from "forge-std/console.sol";

contract MockSocket is ISocket {
    uint32 public immutable chainSlug;

    address public constant fastSwitchboard = address(1);
    address public constant optimisticSwitchboard = address(2);

    error WrongSiblingPlug();
    error WrongIntegrationType();

    struct PlugConfig {
        address siblingPlug;
        address inboundSwitchboard;
        address outboundSwitchboard;
    }

    // switchboard => siblingChainSlug => exists
    mapping(address => mapping(uint256 => bool)) public configExists;
    // plug => siblingChainSlug => config(inboundSwitchboard, outboundSwitchboard, siblingPlug)
    mapping(address => mapping(uint256 => PlugConfig)) public plugConfigs;

    error InvalidConnection();

    constructor(uint32 chainSlug_, uint256 siblingChainSlug_) {
        chainSlug = chainSlug_;

        configExists[fastSwitchboard][siblingChainSlug_] = true;
        configExists[optimisticSwitchboard][siblingChainSlug_] = true;

        configExists[fastSwitchboard][chainSlug_] = true;
        configExists[optimisticSwitchboard][chainSlug_] = true;
    }

    function connect(
        uint32 siblingChainSlug_,
        address siblingPlug_,
        address inboundSwitchboard_,
        address outboundSwitchboard_
    ) external override {
        if (
            !configExists[inboundSwitchboard_][siblingChainSlug_]
                || !configExists[outboundSwitchboard_][siblingChainSlug_]
        ) revert InvalidConnection();

        PlugConfig storage plugConfig = plugConfigs[msg.sender][siblingChainSlug_];

        plugConfig.siblingPlug = siblingPlug_;
        plugConfig.inboundSwitchboard = inboundSwitchboard_;
        plugConfig.outboundSwitchboard = outboundSwitchboard_;

        emit PlugConnected(
            msg.sender,
            siblingChainSlug_,
            siblingPlug_,
            inboundSwitchboard_,
            outboundSwitchboard_,
            address(0),
            address(0)
        );
    }

    function outbound(uint32 siblingChainSlug_, uint256 minMsgGasLimit_, bytes32, bytes32, bytes calldata payload_)
        external
        payable
        override
        returns (bytes32)
    {
        PlugConfig memory srcPlugConfig = plugConfigs[msg.sender][siblingChainSlug_];

        PlugConfig memory dstPlugConfig = plugConfigs[srcPlugConfig.siblingPlug][chainSlug];

        // if (dstPlugConfig.siblingPlug != msg.sender) revert WrongSiblingPlug();

        IPlug(srcPlugConfig.siblingPlug).inbound{gas: minMsgGasLimit_}(chainSlug, payload_);
        return bytes32(0);
    }

    function getPlugConfig(address plugAddress_, uint32 siblingChainSlug_)
        external
        view
        returns (
            address siblingPlug,
            address inboundSwitchboard__,
            address outboundSwitchboard__,
            address capacitor__,
            address decapacitor__
        )
    {
        PlugConfig memory plugConfig = plugConfigs[plugAddress_][siblingChainSlug_];
        return (
            plugConfig.siblingPlug,
            plugConfig.inboundSwitchboard,
            plugConfig.outboundSwitchboard,
            address(0),
            address(0)
        );
    }

    // ignore other functions
    function execute(
        ISocket.ExecutionDetails calldata executionDetails_,
        ISocket.MessageDetails calldata messageDetails_
    ) external payable override {}

    function getMinFees(
        uint256 minMsgGasLimit_,
        uint256 payloadSize_,
        bytes32 executionParams_,
        bytes32 transmissionParams_,
        uint32 remoteChainSlug_,
        address plug_
    ) external view override returns (uint256 totalFees) {}

    function seal(uint256 batchSize_, address capacitorAddress_, bytes calldata signature_) external payable override {}

    function proposeForSwitchboard(bytes32 packetId_, bytes32 root_, address switchboard_, bytes calldata signature_)
        external
        payable
        override
    {}

    function registerSwitchboardForSibling(
        uint32 siblingChainSlug_,
        uint256 maxPacketLength_,
        uint256 capacitorType_,
        address siblingSwitchboard_
    ) external override returns (address capacitor, address decapacitor) {}

    function useSiblingSwitchboard(uint32 siblingChainSlug_, address siblingSwitchboard_) external override {}

    function packetIdRoots(bytes32 packetId_, uint256 proposalCount_, address switchboard_)
        external
        view
        override
        returns (bytes32)
    {}

    function proposalCount(bytes32 packetId_) external view override returns (uint256) {}

    function transmitManager__() external view override returns (ITransmitManager) {}

    function executionManager__() external view override returns (IExecutionManager) {}
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "account-abstraction/core/BasePaymaster.sol";

import "account-abstraction/core/Helpers.sol";
import "account-abstraction/core/UserOperationLib.sol";

/**
 * @title DemoAdminPaymaster
 * @dev A paymaster used in DEMO ONLY ON TESTNET to sponsor admin operations such as CABPaymaster registration in the
 *      invoice manager.
 *      IT OBVIOUSLY SHOULD NOT BE USED IN PRODUCTION nor in real e2e tests (yes, people are looking after your free Sepolia)
 */
contract DemoAdminPaymaster is BasePaymaster {
    address public constant ENTRY_POINT_V7 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    constructor(address _owner) BasePaymaster(IEntryPoint(ENTRY_POINT_V7), _owner) {}

    function _validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 requiredPreFund)
        internal
        override
        returns (bytes memory context, uint256 validationData)
    {
        // NOTE: sponsor everything
        // NOTE: return empty context to skip _postOp: https://eips.ethereum.org/EIPS/eip-4337
        return ("", 0);
    }

    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256 actualUserOpFeePerGas)
        internal
        override
    {}
}

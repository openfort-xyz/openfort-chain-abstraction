// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVault} from "./IVault.sol";

/**
 * @title Interface for the YieldVault contract.
 */
interface IYieldVault is IVault {
    /**
     * @notice Deposits the underlying token into the strategy.
     * @return newShares The amount of shares rewared to the depositer.
     */
    function depositToYield() external returns (uint256);
}

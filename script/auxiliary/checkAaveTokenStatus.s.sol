// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {AaveProtocolDataProvider} from "aave-v3-origin/core/contracts/misc/AaveProtocolDataProvider.sol";
import {console} from "forge-std/console.sol";

contract CheckAaveTokenStatus is Script {
    /**
     * @notice Check if a token is active in the Aave protocol.
     * @dev Queries the protocol data provider to verify the token status.
     * @param protocolDataProvider The address of the Aave Protocol Data Provider contract.
     * @param token The address of the token to check.
     * @return bool True if the token is active, false otherwise.
     */
    function isAaveToken(address protocolDataProvider, address token) public view returns (bool) {
        AaveProtocolDataProvider dataProvider = AaveProtocolDataProvider(protocolDataProvider);

        // Get reserve data for the token
        (,,,,,,,, bool isActive,) = dataProvider.getReserveConfigurationData(token);

        console.log("Token:", token, "Active:", isActive);

        return isActive;
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {IInvoiceManager} from "../interfaces/IInvoiceManager.sol";

library LibEncoders {
    function encode(IInvoiceManager.RepayTokenInfo[] memory repayTokens) internal pure returns (bytes memory encodedRepayToken) {
        for (uint8 i = 0; i < repayTokens.length; i++) {
            encodedRepayToken = bytes.concat(
                encodedRepayToken,
                bytes20(address(repayTokens[i].vault)),
                bytes32(repayTokens[i].amount),
                bytes32(repayTokens[i].chainId)
            );
        }
        return abi.encodePacked(uint8(repayTokens.length), encodedRepayToken);
    }
}

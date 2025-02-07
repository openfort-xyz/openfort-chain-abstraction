// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LibTokens {
    using SafeERC20 for IERC20;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event SupportedTokenAdded(address token);
    event SupportedTokenRemoved(address token);

    struct TokensStore {
        address[] tokens;
        mapping(address => bool) supported;
    }

    function addSupportedToken(TokensStore storage store, address token) public {
        require(!store.supported[token], "TokenManager: token already supported");
        store.supported[token] = true;
        store.tokens.push(token);
    }

    function removeSupportedToken(TokensStore storage store, address token) public {
        if (token == NATIVE_TOKEN) {
            require(address(this).balance == 0, "TokenManager: native token has balance");
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            require(balance == 0, "TokenManager: token has balance");
        }

        uint256 length = store.tokens.length;
        for (uint256 i = 0; i < length;) {
            if (store.tokens[i] == token) {
                store.supported[token] = false;
                store.tokens[i] = store.tokens[length - 1];
                store.tokens.pop();
                break;
            }
            unchecked {
                i++;
            }
        }
    }

    function withdraw(address recipient, address token, uint256 amount) public {
        if (token == NATIVE_TOKEN) {
            (bool success,) = payable(recipient).call{value: amount}("");
            require(success, "TokenManager: native token transfer failed");
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    function getSupportedTokens(TokensStore storage store) public view returns (address[] memory) {
        return store.tokens;
    }
}

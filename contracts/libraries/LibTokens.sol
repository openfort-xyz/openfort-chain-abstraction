// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LibTokens {
    using SafeERC20 for IERC20;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    error NativeTokenTransferFailed();

    event SupportedTokenAdded(address token);
    event SupportedTokenRemoved(address token);
    event RageQuitCompleted(address recipient);

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
        require(store.supported[token], "TokenManager: token not supported");
        require(getTokenBalance(token) == 0, "TokenManager: token has balance");

        uint256 length = store.tokens.length;
        for (uint256 i = 0; i < length;) {
            if (store.tokens[i] == token) {
                store.supported[token] = false;
                // Note: ordering doesn't matter
                store.tokens[i] = store.tokens[length - 1];
                store.tokens.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function rageQuit(TokensStore storage store, address recipient) public {
        for (uint256 i = 0; i < store.tokens.length; ++i) {
            transferToken(store.tokens[i], recipient, getTokenBalance(store.tokens[i]));
        }
    }

    function getSupportedTokens(TokensStore storage store) public view returns (address[] memory) {
        return store.tokens;
    }

    function getTokenBalance(address token) public view returns (uint256) {
        return token == NATIVE_TOKEN ? address(this).balance : IERC20(token).balanceOf(address(this));
    }

    function frontToken(address token, address recipient, uint256 amount) internal {
        // NOTE: use forceApprove to support tokens that require the approval
        // to be set to zero before setting it to a non-zero value, such as USDT.
        token == NATIVE_TOKEN ? _transferNative(recipient, amount) : IERC20(token).forceApprove(recipient, amount);
    }

    function transferToken(address token, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        token == NATIVE_TOKEN ? _transferNative(recipient, amount) : _transferERC20(token, recipient, amount);
    }

    function _transferNative(address recipient, uint256 amount) private {
        (bool success,) = payable(recipient).call{value: amount}("");
        if (!success) revert NativeTokenTransferFailed();
    }

    function _transferERC20(address token, address recipient, uint256 amount) private {
        // revert SafeERC20FailedOperation on failure
        IERC20(token).safeTransfer(recipient, amount);
    }
}

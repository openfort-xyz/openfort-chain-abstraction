// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MiniPair.sol";

contract MiniFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 fee);

    function createPair(address tokenA, address tokenB, uint256 fee) external returns (address pair) {
        require(tokenA != tokenB, "MiniFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "MiniFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "MiniFactory: PAIR_EXISTS");

        pair = address(new MiniPair(token0, token1, fee));
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in both directions
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, fee);
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.9;

import "./interfaces/IFactory.sol";
import "./Pair.sol";

contract Factory is IFactory {
    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address token0, address token1)
        external
        override
        returns (address pair)
    {
        require(token0 != token1, "FACTORY: IDENTICAL_ADDRESSES");
        (address tokenA, address tokenB) = token0 < token1
            ? (token0, token1)
            : (token1, token0);
        require(tokenA != address(0), "FACTORY: ZERO_ADDRESS");
        require(getPair[tokenA][tokenB] == address(0), "FACTORY: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IPair(pair).initialize(tokenA, tokenB);
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(tokenA, tokenB, pair, allPairs.length);
    }
}
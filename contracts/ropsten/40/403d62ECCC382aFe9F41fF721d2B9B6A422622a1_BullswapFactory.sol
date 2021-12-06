pragma solidity ^0.8.9;
// SPDX-License-Identifier: MIT

import './interfaces/IBullswapPair.sol';
import './BullswapPair.sol';

contract BullswapFactory {
    address public feeTo1;
    address public feeTo2;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor() {
        feeToSetter = msg.sender;
        feeTo1 =msg.sender;
        feeTo2 = msg.sender;

    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'Bullswap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Bullswap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Bullswap: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(BullswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IBullswapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function getInitHash() public pure returns(bytes32){
        bytes memory bytecode = type(BullswapPair).creationCode;
        return keccak256(abi.encodePacked(bytecode));
    }

    function setFeeTo1(address _feeTo1) external {
        require(msg.sender == feeToSetter, 'Bullswap: FORBIDDEN');
        feeTo1 = _feeTo1;
    }

    function setFeeTo2(address _feeTo2) external {
        require(msg.sender == feeToSetter, 'Bullswap: FORBIDDEN');
        feeTo2 = _feeTo2;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'Bullswap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
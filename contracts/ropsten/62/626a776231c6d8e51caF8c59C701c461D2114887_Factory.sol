// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../interfaces/IFactory.sol";
import "./Core.sol";

contract Factory is IFactory {
    address public override feeTo;
    address public override feeToSetter;
    address public override buyback;

    address public override migrator;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    constructor(address _feeToSetter) public {
        require(
            _feeToSetter != address(0),
            "HODL:constructor:: ZERO_ADDRESS_FEE_TO_SETTER"
        );

        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(Core).creationCode);
    }

    function createPair(address tokenA, address tokenB)
        external
        override
        returns (address pair)
    {
        require(tokenA != tokenB, "HODL: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "HODL: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "HODL: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(Core).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        Core(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "HODL: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setMigrator(address _migrator) external override {
        require(msg.sender == feeToSetter, "HODL: FORBIDDEN");
        migrator = _migrator;
    }

    function setBuyback(address _buyback) external override {
        require(msg.sender == feeToSetter, "HODL: FORBIDDEN");
        buyback = _buyback;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "HODL: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
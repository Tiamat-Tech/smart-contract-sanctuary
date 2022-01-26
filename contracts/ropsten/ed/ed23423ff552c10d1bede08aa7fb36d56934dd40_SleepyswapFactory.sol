pragma solidity ^0.8.4;

import "./interfaces/ISleepyswapFactory.sol";
import "./SleepyswapPair.sol";

contract SleepyswapFactory is ISleepyswapFactory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    // event PairCreated(
    //     address indexed token0,
    //     address indexed token1,
    //     address pair,
    //     uint256
    // );

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external override view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB)
        external
        override
        returns (address pair)
    {
        require(tokenA != tokenB, "Sleepyswap: IDENTICAL_ADDRESS");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "Sleepyswap: ZERO addresss");
        require(
            getPair[token0][token1] == address(0),
            "Sleepyswap: PAIR_EXISTED"
        );
        bytes memory bytecode = type(SleepyswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        ISleepyswapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "Sleepyswap: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "Sleepyswap: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
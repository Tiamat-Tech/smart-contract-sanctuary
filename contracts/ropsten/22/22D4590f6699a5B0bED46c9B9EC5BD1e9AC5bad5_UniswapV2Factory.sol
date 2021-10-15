// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

// import "@openzeppelin/contracts/access/Ownable.sol";

contract UniswapV2Factory is IUniswapV2Factory {
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    // address[] public allPairs; // storage of all pairs
    uint public override allPairs;

    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));
    
    uint256 releaseTime;
    uint256 lockTime = 2 days;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
        releaseTime = block.timestamp;
    }

    function allPairsLength() external override view returns (uint) {
        // return pair length
        // return allPairs.length;
        return allPairs;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'PolkaBridge AMM V1: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PolkaBridge AMM V1: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'PolkaBridge AMM V1: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        // allPairs.push(pair);
        allPairs++;
        // emit PairCreated(token0, token1, pair, allPairs.length);
        emit PairCreated(token0, token1, pair, allPairs);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'PolkaBridge AMM V1: FORBIDDEN');
        // if(releaseTime == 0)
            
        // if(releaseTime != 0)
        {
            // if(feeTo != address(0))
            //     require(block.timestamp - releaseTime >= lockTime, "current time is before release time");
            // releaseTime = 0;
            feeTo = _feeTo;
            emit SetFeeTo(_feeTo);    
        }        
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'PolkaBridge AMM V1: FORBIDDEN');
        // if(releaseTime == 0)
            // releaseTime = block.timestamp;
        // if(releaseTime != 0)
        {
            if(feeToSetter != address(0))
                require(block.timestamp - releaseTime >= lockTime, "current time is before release time");
            // releaseTime = 0;
            feeToSetter = _feeToSetter;
            emit SetFeeToSetter(_feeToSetter);
        }        
    }

    function test_timeStamp() external override view returns (uint)
    {
        return block.timestamp;
    }

    function test_releaseTime() external override view returns (uint)
    {
        return releaseTime;
    }

    function test_Diff() external override view returns (uint)
    {
        return block.timestamp - releaseTime;
    }

    function test_locktime() external override view returns (uint)
    {
        return lockTime;
    }

    function test_addressZero() external override pure returns (address)
    {
        return address(0);
    }

    function test_Require(uint _delay) external override
    {
        require(block.timestamp >= _delay, 'current time is before release time');
    }

}
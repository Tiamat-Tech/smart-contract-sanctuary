//SPDX-License-Identifier: Unlicense.
pragma solidity ^0.8.0;

import "./IAnotherCounter.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Counters library by OpenZeppelin
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol
// https://solidity-by-example.org/first-app/
contract AnotherCounter is IAnotherCounter, Ownable {
    using SafeCast for int256;
    using Strings for uint256;

    uint256 private count;

    function get() external view override returns (uint256) {
        return count;
    }

    function increaseByOne() external override {
        // Solidity >= 0.8.0 checks for overflow
        // No need for OpenZeppelin SafeMath
        count += 1;
        emit CountChanged(count - 1, count);
    }

    function decreaseByOne() external override {
        // Solidity >= 0.8.0 checks for underflow
        // No need for OpenZeppelin SafeMath
        count -= 1;
        emit CountChanged(count + 1, count);
    }

    function increaseByAmount(int256 amount) external override {
        // Use OpenZeppelin SafeCast to cast from int256 to uint256
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol
        uint256 _amount = SafeCast.toUint256(amount);
        count = count + _amount;
        emit CountChanged(count - _amount, count);
    }

    function xorWithSenderAddress() external view override returns (bytes32) {
        return bytes32(uint256(uint160(msg.sender)) << 96) ^ bytes32(count);
    }

    function reset() external override onlyOwner {
        uint256 _count = count;
        count = 0;
        emit CountChanged(_count, count);
    }

    function toAsciiHexString() external view override returns (string memory) {
        // Strings library from OpenZeppelin includes toHexString
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol
        return Strings.toHexString(count);
    }
}
/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.7 <0.9.0;

interface Calculator {
    function add(uint a, uint b) external pure returns(uint);
    function mul(uint a, uint b) external pure returns(uint);
}

contract ArrayCalculator {
    Calculator calculator;

    constructor(address _calculator) {
        calculator = Calculator(_calculator);
    }

    function sum(uint[] calldata _array) external view returns(uint) {
        uint sum_ = 0;
        for (uint i = 0; i < _array.length; ++i) {
            sum_ = calculator.add(sum_, _array[i]);
        }
        return sum_;
    }

    function product(uint[] calldata _array) external view returns(uint) {
        uint product_ = 1;
        for (uint i = 0; i < _array.length; ++i) {
            product_ = calculator.mul(product_, _array[i]);
        }
        return product_;
    }
}
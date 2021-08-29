/**
 *Submitted for verification at Etherscan.io on 2021-08-29
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

contract Child {
    function min() public pure returns (int256) {
        return type(int256).min;
    }
    
    function max() public pure returns (int256) {
        return type(int256).max;
    }
}

contract Parent {
    Child[] public contracts;
    function deploy() public {
        Child c1 = new Child();
        Child c2 = new Child();
        Child c3 = new Child();
        Child c4 = new Child();
        Child c5 = new Child();
        contracts.push(c1);
        contracts.push(c2);
        contracts.push(c3);
        contracts.push(c4);
        contracts.push(c5);
    }
}
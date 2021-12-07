/**
 *Submitted for verification at Etherscan.io on 2021-12-07
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.10;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
contract Storage {

    uint256 number;

    constructor(){

    }
    /*
    *d dadasd
    */
    function getNum()public view returns(uint256){
        return number;
    }
}
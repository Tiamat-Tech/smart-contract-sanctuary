/**
 *Submitted for verification at Etherscan.io on 2022-02-10
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract HelloWord{
    string private data;
    function write(string memory _data) public{
        data = _data;
    } 

    function read() public view returns (string memory){
        return data;
    }
}
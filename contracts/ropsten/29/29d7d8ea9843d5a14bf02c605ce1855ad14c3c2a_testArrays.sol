/**
 *Submitted for verification at Etherscan.io on 2021-05-04
*/

pragma solidity ^0.6.0;


contract testArrays {
    
    bool[] public b;
    
    function enterArrayOfBoolean(bool[] memory _a) public {
        for (uint8 i = 0; i < _a.length; i++) {
            b.push(_a[i]);
        }
    }
}
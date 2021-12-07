/**
 *Submitted for verification at Etherscan.io on 2021-12-07
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.4.0;

contract Test {
    
    uint256 start = 5;
    mapping(uint256 => string) ok;
    uint256[] _arrMap;

    function setMap(uint256 a) public  {
        _arrMap.push(a);
    }
    function setStart(uint256 a) public{
        start = a;
    }
    function getStart() public view returns(uint256){
        // start = 0;
        return start;
    }
    function getMap() public view returns(uint256[] memory)
    {
        return _arrMap;
    }
    function delMap() public{
        delete _arrMap;
    }
}
/**
 *Submitted for verification at Etherscan.io on 2021-04-22
*/

pragma solidity ^0.4.24;
contract Hello {
    string public name;
    constructor() public {
        name = "108403523!";
    }
    function setName(string _name) public {
        name = _name;
    }
}
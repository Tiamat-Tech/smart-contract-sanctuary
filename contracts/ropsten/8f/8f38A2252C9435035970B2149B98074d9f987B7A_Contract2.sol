/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

pragma solidity ^0.8.11;

contract Contract1 {
    function function1(uint8 _x, uint8 _y) internal pure returns(uint, string memory) {
        return(_x + _y - 5, "Result from function1 Contract1");
    }

    function function2(string memory _name) internal pure returns(string memory, string memory) {
        string memory name = _name;
        return(name, "Result from function2 Contract1");
    }
}

contract Contract2 is Contract1 {
    function function3(uint8 _x, uint8 _y) public pure returns (uint, string memory){
        return (function1(_x, _y));
    }
    
    function function4(string memory _name) public pure returns (string memory, string memory) {
        return (function2(_name));
    }
}
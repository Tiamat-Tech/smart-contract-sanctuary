/**
 *Submitted for verification at Etherscan.io on 2022-01-31
*/

pragma solidity >=0.7.0 <0.8.0;contract Homework {
    mapping(address => string) public submitters;
    function store(string memory student_id) public {
        submitters[msg.sender] = student_id;
    }
}
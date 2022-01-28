/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

pragma solidity ^0.8.11;

contract ContractOne {
    mapping(address => bool) public AccessList;

    function addAccess(address _addressContract) public {
        AccessList[_addressContract] = true;
    }

    function callFunction(address _addr, uint8 _value1, uint8 _value2) public view returns(uint, string memory) {
        require(AccessList[_addr] == true, "Access denied");
        return(_value1 * _value2, "Access received");
    }
}

contract ContractTwo {

    function callAccess(address _contractOneAddress, address _addressThisContract) public {
        ContractOne contract1 = ContractOne(_contractOneAddress);
        contract1.addAccess(_addressThisContract);
    }

    function test(address _addressContractOne, address _addThisContract, uint8 _x, uint8 _y) public view returns(uint, string memory) {
        ContractOne contract1 = ContractOne(_addressContractOne);
        return (contract1.callFunction(_addThisContract, _x, _y));
    }
}
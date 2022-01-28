/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

pragma solidity ^0.8.11;

contract ContractOne {
    mapping(address => bool) public AccessList;

    function addAccess(address _addressContract) public {
        AccessList[_addressContract] = true;
    }

    // функция, которую вызываем только из ContractTwo
    function callFunction(address _addr, uint8 _value1, uint8 _value2) public view returns(uint, string memory) {
        require(AccessList[_addr] == true, "Access denied");
        return(_value1 * _value2, "Access received");
    }
}
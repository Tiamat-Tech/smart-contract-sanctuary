// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {

    mapping(address => bool) public blockAddress;

    constructor() ERC20("MyToken", "MT", 10000000000) {}

    modifier onlyAllowed() {
        require(blockAddress[msg.sender] == false, "Address is blacklisted");
        _;
    }

    function blacklistAddress(address _target) public onlyOwner() returns(bool) {
        require(blockAddress[_target] == true, "Address is already blacklisted");
        blockAddress[_target] = true;
        return true;
    }

    function whitelistAddress(address _target) public onlyOwner() returns(bool) {
        require(blockAddress[_target] == false, "Address is already whitelisted");
        blockAddress[_target] = false;
        return true;
    } 

    function special_transfer(address _to, uint _amount) public onlyAllowed() returns (bool) {
        transfer(_to, _amount);
        return true;
    }

}
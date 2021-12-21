//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MalevichToken is ERC20, Ownable {
    mapping(address=>bool) private _wards;

    modifier onlyMinter() {
        require(owner() == _msgSender() || _wards[msg.sender], "MalevichToken: caller is not the minter");
        _;
    }
    constructor() ERC20("MalevichToken", "MTN") {
        
    }

    function mint(address account, uint256 amount) external onlyMinter returns (bool){
        _mint(account, amount);
        return true;
    }

    function allow(address account) external onlyOwner {
        require (account != address(0), "MalevichToken: address must not be empty");
        _wards[account] = true;
    }

    function deny(address account) external onlyOwner {
        require (account != address(0), "MalevichToken: address must not be empty");
        _wards[account] = false;
    }

    function getWards(address account) view external returns (bool) {
        require (account != address(0), "MalevichToken: address must not be empty");
        return _wards[account];
    }
}
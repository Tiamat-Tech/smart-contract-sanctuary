// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TEQ is ERC20, Ownable {
    mapping(address => uint256) private _limitTransfer;

    constructor() ERC20("TEQ", "TEQ") {}
    
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
    
    function setLimitTransfer(address account, uint256 limit) external onlyOwner {
        _limitTransfer[account] = limit;
    }
    
    function limitTransfer(address account) public view returns (uint256) {
        return _limitTransfer[account];
    }
    
    function privateTransfer(address recipient, uint256 amount) external {
        require(_limitTransfer[_msgSender()] >= amount);
        
        _limitTransfer[_msgSender()] -= amount;
        _mint(_msgSender(), amount);
        _transfer(_msgSender(), recipient, amount);
    }
}
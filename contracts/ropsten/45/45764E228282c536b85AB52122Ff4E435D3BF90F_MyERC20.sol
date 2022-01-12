// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyERC20 is ERC20, Ownable {
	mapping(address => bool) _whitelisteds;
	
	constructor() ERC20("MyERC20", "MyERC20") {
		addWhitelisted(msg.sender);
		_mint(msg.sender, 10000);
	}
	
	function addWhitelisted(address account) public onlyOwner returns (bool) {
		require(account != address(0));
		_whitelisteds[account] = true;
		return true;
	}
	
	function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(_whitelisteds[msg.sender]);
		_transfer(_msgSender(), recipient, amount);
        return true;
    }
}
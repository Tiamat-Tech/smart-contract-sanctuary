// SPDX-License-Identifier: MIT
pragma solidity ^0.8; 

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract XPNet is ERC1155, Ownable {
	mapping (uint256=>string) public uris;

	constructor() ERC1155("XPWRP") {} // solhint-disable-line no-empty-blocks

	function mint(address to, uint256 id, uint256 amount) public onlyOwner {
		_mint(to, id, amount, "");
	}

	function burn(address from, uint256 id, uint256 amount) public onlyOwner {
		_burn(from, id, amount);
	}
}
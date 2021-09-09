// SPDX-License-Identifier: MIT
pragma solidity =0.8.6;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Burnable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

contract WrappedToken is IERC20, ERC20Burnable, Ownable {
	constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

	function mint(address account, uint256 amount) external onlyOwner {
		_mint(account, amount);
	}
}
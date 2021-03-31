// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniToken is ERC20Capped, Ownable {
    constructor (string memory name, string memory symbol, uint256 cap)
        ERC20(name, symbol) ERC20Capped(cap)
    { }

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }
}
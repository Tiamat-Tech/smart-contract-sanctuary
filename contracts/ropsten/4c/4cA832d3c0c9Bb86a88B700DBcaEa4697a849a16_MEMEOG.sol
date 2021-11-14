// contracts/MEME.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract MEMEOG is ERC20, ERC20Capped, ERC20Burnable {
    constructor() ERC20("MEME (OG) TEST", "MEME") ERC20Capped(28000) {}

    function decimals() public view virtual override(ERC20) returns (uint8) {
        return 8;
    }

    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        super._mint(account, amount);
    }
}
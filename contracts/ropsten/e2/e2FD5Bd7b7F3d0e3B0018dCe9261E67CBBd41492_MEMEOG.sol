// contracts/MEME.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract MEMEOG is ERC20, ERC20Burnable {
    constructor() ERC20("MEME (OG) TEST", "MEME") {
        _mint(_msgSender(), 28000 * (10**uint256(8)));
    }

    function decimals() public view virtual override(ERC20) returns (uint8) {
        return 8;
    }
}
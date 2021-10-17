// contracts/FakeBrainz.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract FakeBrainz is ERC20Burnable, Ownable {
    constructor() ERC20("FakeBrainz", "FBRAIN$") {}
    function iWantBRAINS(uint amount) external {
        _mint(msg.sender, amount);
    }
}
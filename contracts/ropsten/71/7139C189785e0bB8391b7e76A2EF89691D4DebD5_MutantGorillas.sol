// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "Ownable.sol";
import "ERC721.sol";
import "ERC721URIStorage.sol";
import "Strings.sol";

contract MutantGorillas is ERC721URIStorage, Ownable {
    uint256 public totalGorillas;
    event MintGor(address indexed sender, uint256 startWith);

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}

    function mint(uint256 _times) public {
        emit MintGor(_msgSender(), totalGorillas + 1);
        for (uint256 i = 0; i < _times; i++) {
            _mint(_msgSender(), 1 + totalGorillas++);
        }
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC721.sol";
import "ERC721Enumerable.sol";
import "Counters.sol";
import "Ownable.sol";

contract MutantTestCats is ERC721Enumerable, Ownable {
    uint256 public totalTestCats;
    event MintCat(address indexed sender, uint256 startWith);

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}

    function tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 count = balanceOf(owner);
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = tokenOfOwnerByIndex(owner, i);
        }
        return ids;
    }

    function mint(uint256 _times) public payable {
        payable(owner()).transfer(msg.value);
        emit MintCat(_msgSender(), totalTestCats + 1);
        for (uint256 i = 0; i < _times; i++) {
            _mint(_msgSender(), 1 + totalTestCats++);
        }
    }
}
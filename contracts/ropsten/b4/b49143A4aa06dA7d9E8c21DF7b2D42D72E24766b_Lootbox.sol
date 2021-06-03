//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";
import "./LootBoxRandomness.sol";

contract Lootbox is ERC721URIStorage {

    using Counters for Counters.Counter;
    using LootBoxRandomness for LootBoxRandomness.LootBoxRandomnessState;

    string private _baseTokenURI;
    Counters.Counter private _tokenIds;
    LootBoxRandomness.LootBoxRandomnessState state;
    
    constructor(string memory baseTokenURI) ERC721("Lootbox", "LOOT") {
        _baseTokenURI = baseTokenURI;
    }

    function mint() public returns (uint256) {
        _tokenIds.increment();

        uint256 newLootboxId = _tokenIds.current();
        _safeMint(msg.sender, newLootboxId);
        
        return newLootboxId;
    }

    function open(uint256 tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not owner or approved"
        );

        console.log("Burned lootbox: ", tokenId);
        _burn(tokenId);
    }

    function setTokenIdsForClass(
        uint256 _classId,
        uint256[] memory tokenIds
    ) public {
        LootBoxRandomness.setTokenIdsForClass(state, _classId, tokenIds);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
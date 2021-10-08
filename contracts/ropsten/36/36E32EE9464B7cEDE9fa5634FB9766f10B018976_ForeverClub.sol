//SPDX-License-Identifier: UNLICENSED

/*
ForeverClub is an NFT that can't be bought or sold.
Only be transferred, to bootstrap crypto communities.
Rules: 
 * Mint ForeverClub NFT
   * give it a name
   * decide the size of the club
 * Minter transfers to second member
 * Second transfers to third and so on
 * This goes on until club reaches it's size
 * NFT burnt if there is no transfer in 24 hrs
 * All the transfer amounts become part of treasury [Optional]
 * Treasury is controlled by the members through voting [Optional]
We're launching Forever ETH club. Someone can launch Forever Solana club.
Long tail communities can be bootstrapped using this.
An NFT is forever. No more trade humping forever. 
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ForeverClub is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    struct Owner {
        address addr;
    }

    mapping(uint256 => uint256) _clubSize;
    mapping(uint256 => uint256) _membersCount;
    mapping(uint256 => uint256) _transferTimestamp;
    mapping(uint256 => Owner[]) _ownershipSnapshot;

    constructor() ERC721("ForeverClub", "FOREVER") {}

    function createNFT(address owner, string memory tokenURI, uint256 limit) 
        public returns (uint256) 
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current() * 10 + limit;
        _clubSize[newItemId] = limit;
        _transferTimestamp[newItemId] = block.timestamp;

        _mint(owner, newItemId);

        _membersCount[newItemId] = 1;

        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal virtual override
    {
        super._beforeTokenTransfer(from, to, tokenId);
        _validateTransfer(tokenId);
        _transferTimestamp[tokenId] = block.timestamp;
        _membersCount[tokenId] += 1;
        _ownershipSnapshot[tokenId].push(Owner(to));
    }

    function _validateTransfer(uint256 tokenId) private {
        require(_membersCount[tokenId] < _clubSize[tokenId], "Club membership full. No transfers possible.");
        if(block.timestamp > (_transferTimestamp[tokenId] + 1 minutes)) {
            _burn(tokenId);
            revert("Transfer not possible, NFT burnt!");
        }
    }

    // function _transfer(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) internal virtual override {
    //     _transferTimestamp[tokenId] = block.timestamp;
    //     _membersCount[tokenId] += 1;
    //     _ownershipSnapshot[tokenId].push(Owner(to));
    //     super._transfer(from, to, tokenId);
    // }
    
    function getTrailAtIndex(uint256 tokenId, uint256 index) public view returns (address) {
        return _ownershipSnapshot[tokenId][index].addr;
    }
}
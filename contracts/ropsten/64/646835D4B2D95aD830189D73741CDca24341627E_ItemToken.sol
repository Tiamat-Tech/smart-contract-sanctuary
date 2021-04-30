// contracts/ItemToken.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract ItemToken is  Ownable, ERC721URIStorage {
    uint256 private _cap = 5;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;
    constructor() public ERC721("ItemToken","ITEM"){

    }

    function mintItem(address to, string memory tokenURI)
        public
        onlyOwner
        returns(string memory)
    {

        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(to, id);
        _setTokenURI(id, tokenURI);
        return("The transaction went through! Item minted!");
    }

    function burnItem(uint256 id, string memory tokenURI)
        public
        onlyOwner
    {
        _burn(id);
        hashes[tokenURI] = 0;
        _tokenIds.decrement();
    }
}
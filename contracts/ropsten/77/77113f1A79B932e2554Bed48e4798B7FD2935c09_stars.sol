// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract stars is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address private _owner;

    constructor() ERC721("STARS EXCHANGE", "STARS"){
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner,"Must be the creator");
        _;
    }

    function mint(address to, string memory tokenURI) public onlyOwner returns (uint256)  {
        _tokenIds.increment();

        uint256 tokenId = _tokenIds.current();
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }
}
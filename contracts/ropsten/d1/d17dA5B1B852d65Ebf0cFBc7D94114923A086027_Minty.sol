//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Owner {
    address internal owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        // TODO: remove the logs!
        require(msg.sender == owner);
        _; 
    }
}

contract Minty is ERC721URIStorage, Owner {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 private METADATA_TOKEN_ID = 0;

    // tokenid to boolean.
    // the token could be minted only once!!! 
    // meaning... white canvas is the original state, and then the artist can perform his/her
    // magic, but... when the magic has been done, it has to be finite!
    mapping(uint256 => bool) private _minted;

    constructor() ERC721("MintyTest", "MINT_T") {
    }
    
    function mintToken(address owner, string memory metadataURI)
    public onlyOwner
    returns (uint256)
    {
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _safeMint(owner, id);
        _setTokenURI(id, metadataURI);

        return id;
    }

    // this function should be used ONLY by the owner of the contract/token
    function updateMetaToken(string memory metadataURI) public {
        updateToken(METADATA_TOKEN_ID, metadataURI);
    }
    // for test purposes it was made as public.
    // it should be either private or used only by the owner of the contract as the method above.
    function updateToken(uint256 tokenId, string memory metadataURI) public {
        require(msg.sender == ownerOf(tokenId), "TokenId could be updated only the the address which owns it");
        require(!_minted[tokenId], "TokenId was already updated once. You can not update the same token more than once");
        _setTokenURI(tokenId, metadataURI);
        _minted[tokenId] = true;
    }
}
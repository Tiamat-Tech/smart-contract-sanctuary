//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Owner {
    address internal owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _; 
    }
}

contract TestDot1 is ERC721URIStorage, Owner, ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 private METADATA_TOKEN_ID = 0;
    bool private MINTING_ENABLED = false;
    uint256 private MAX_TOKENS_AMOUNT = 10000;

    // tokenid to boolean.
    // the token could be minted only once!!! 
    // meaning... white canvas is the original state, and then the artist can perform his/her
    // magic, but... when the magic has been done, it has to be finite!
    mapping(uint256 => bool) private _minted;

    constructor() ERC721("TestDot_1", "TSDT1") {
    }

    function enableMint() public onlyOwner {
        require(!MINTING_ENABLED, "Minting is already enabled");
        MINTING_ENABLED = true;
    }
    
    function mintToken(string memory metadataURI) public returns (uint256)
    {   
        require(MINTING_ENABLED, "Minting is not yet enabled");
        require(MAX_TOKENS_AMOUNT >= _tokenIds.current(), "Maximum amount of tokens minted");

        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _safeMint(msg.sender, id);
        // fill metadata with default value
        _setTokenURI(id, metadataURI);

        return id;
    }

    // for test purposes it was made as public.
    // it should be either private or used only by the owner of the contract as the method above.
    function updateToken(uint256 tokenId, string memory metadataURI) public {
        require(msg.sender == ownerOf(tokenId), "TokenId could be updated only the the address which owns it");
        require(!_minted[tokenId], "TokenId was already updated once. You can not update the same token more than once");
        _setTokenURI(tokenId, metadataURI);
        _minted[tokenId] = true;
    }

    function destroyContract() public payable onlyOwner {
        address payable addr = payable(owner);
        selfdestruct(addr);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
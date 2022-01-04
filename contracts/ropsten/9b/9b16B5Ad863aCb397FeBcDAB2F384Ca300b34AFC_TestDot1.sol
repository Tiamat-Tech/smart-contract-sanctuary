//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
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
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public constant MINT_PRICE = 80000000000000000; //0.08 ETH
    uint256 private MAX_TOKENS_AMOUNT = 10000;
    uint256 private MAX_MINT_AMOUNT = 10;
    bool private MINTING_ENABLED = false;
    bool private UPDATE_ENABLED = false;

    mapping(uint256 => bool) private _minted;

    constructor() ERC721("TestDot_1", "TSDT1") {
    }

    function enableMint() public onlyOwner {
        require(!MINTING_ENABLED, "Minting is already enabled");
        MINTING_ENABLED = true;
    }

    function enableUpdate() public onlyOwner {
        require(!UPDATE_ENABLED, "Updating is already enabled");
        UPDATE_ENABLED = true;
    }
    
    function mintToken(string memory metadataURI, uint256 amount) public payable {   
        require(MINTING_ENABLED, "Minting is not yet enabled");
        require(amount <= MAX_MINT_AMOUNT, "You can mint a maximum of 10 tokens per wallet");
        require(totalSupply().add(amount) <= MAX_TOKENS_AMOUNT, "Purchase would exceed maximum supply of tokens");
        require(MAX_TOKENS_AMOUNT >= _tokenIds.current(), "Maximum amount of tokens minted");
        require(MINT_PRICE.mul(amount) <= msg.value, "Ether value sent is not correct");

        for(uint i = 0; i < amount; i++) {
            // uint mintIndex = totalSupply();
            if (totalSupply() < MAX_TOKENS_AMOUNT) {
                _tokenIds.increment();

                uint256 id = _tokenIds.current();
                _safeMint(msg.sender, id);
                _setTokenURI(id, metadataURI);
            }
        }
    }

    function reserveTokens() public onlyOwner {        
        uint supply = totalSupply();
        for (uint i = 0; i < 100; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function updateToken(uint256 tokenId, string memory metadataURI) public {
        require(UPDATE_ENABLED, "Updating tokens is not yet enabled");
        require(msg.sender == ownerOf(tokenId), "TokenId could be updated only the the address which owns it");
        require(!_minted[tokenId], "TokenId was already updated once. You can not update the same token more than once");

        _setTokenURI(tokenId, metadataURI);
        _minted[tokenId] = true;
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function destroyContract() public payable onlyOwner {
        address payable addr = payable(owner);
        selfdestruct(addr);
    }

    // Overrides

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}
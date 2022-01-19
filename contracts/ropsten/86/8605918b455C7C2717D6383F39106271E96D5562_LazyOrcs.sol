//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;
// pragma abicoder v2; // required to accept structs as function parameters

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract LazyOrcs is ERC721URIStorage, ERC721Enumerable, Ownable {

    uint256 public constant MAX_N_NFTS = 10000;

    mapping(address => uint256) public whitelist;
    mapping(address => uint256) public freeMintList;
    mapping(uint256 => bool) revealed;

    uint256 private _freeMintStartDate;
    uint256 private _whitelistMintStartDate;
    uint256 private _whitelistMintEndDate;
    uint256 private _publicMintStartDate;
    uint256 private _publicMintEndDate;

    constructor(uint256 freeMintStartDate, uint256 whitelistMintStartDate, uint256 whitelistMintEndDate,
        uint256 publicMintStartDate, uint256 publicMintEndDate) ERC721("LazyOrcs", "ORX") {
        _freeMintStartDate = freeMintStartDate;
        _whitelistMintStartDate = whitelistMintStartDate;
        _whitelistMintEndDate = whitelistMintEndDate;
        _publicMintStartDate = publicMintStartDate;
        _publicMintEndDate = publicMintEndDate;
    }

    /*
     * Stuff with begin and end dates
     */
    function getStartAndEndDates() public view returns (uint256, uint256, uint256, uint256, uint256) {
        return (_freeMintStartDate, _whitelistMintStartDate, _whitelistMintEndDate, _publicMintStartDate, _publicMintEndDate);
    }
    function setFreeMintStartDate(uint256 date) external onlyOwner {
        _freeMintStartDate = date;
    }
    function setWhitelistMintDates(uint256 begin, uint256 end) external onlyOwner {
        _whitelistMintStartDate = begin;
        _whitelistMintEndDate = end;
    }
    function setPublicMintDates(uint256 begin, uint256 end) external onlyOwner {
        _publicMintStartDate = begin;
        _publicMintEndDate = end;
    }

    /*
     * Whitelist handling
     */
    function addAddressToWhitelist(address _user, uint256 n) external onlyOwner {
        whitelist[_user] = n;
    }
    function addAddressToFreeMintList(address _user, uint256 n) external onlyOwner {
        freeMintList[_user] = n;
    }
    function nWhitelistMints(address _user) public view returns (uint256) {
        return whitelist[_user];
    }
    function nFreeMints(address _user) public view returns (uint256) {
        return freeMintList[_user];
    }

    /* Minting */
    function price() public pure returns (uint256 response) {
        return 0.002 ether;
    }
    function mintOrc(uint256 nOrcs) public payable {
        require(block.timestamp >= _publicMintStartDate, "Public sale has not started");
        require(block.timestamp <= _publicMintEndDate, "Public sale has ended");

        require(totalSupply() < MAX_N_NFTS, "Sale has ended");
        require(nOrcs > 0 && nOrcs <= 5, "Must purchase 1 - 5 NFTs");
        require(msg.value == price() * nOrcs, "Incorrect funds to redeem");
        require(totalSupply() + nOrcs < MAX_N_NFTS, "Number of NFTs exceeds supply");
        for (uint256 i = 0; i < nOrcs; ++i) {
            uint tokenIndex = totalSupply();
            _safeMint(msg.sender, tokenIndex);
        }
    }
    function whitelistMintOrc() public payable {
        require(block.timestamp >= _whitelistMintStartDate, "Whitelist sale has not started");
        require(block.timestamp <= _whitelistMintEndDate, "Whitelist sale has ended");

        require(whitelist[msg.sender] >= 1, "Address not whitelisted");
        require(totalSupply() < MAX_N_NFTS, "Sale has ended");
        require(totalSupply() + 1 < MAX_N_NFTS, "Number of NFTs exceeds supply");
        require(msg.value == price(), "Incorrect funds to redeem");
        whitelist[msg.sender] -= 1;
        _safeMint(msg.sender, totalSupply());
    }
    function freeMintOrc() public {
        require(block.timestamp >= _freeMintStartDate, "Free mint sale has not started");
        require(freeMintList[msg.sender] >= 1, "Address not eligible for free minting");
        freeMintList[msg.sender] -= 1;
        _safeMint(msg.sender, totalSupply());
    }
    function reveal(uint256 tokenId, string memory uri) onlyOwner public {
        require(_exists(tokenId), "Orcs: URI query for nonexistent token");
        require(!revealed[tokenId], "Orcs: already revealed");
        _setTokenURI(tokenId, uri);
        revealed[tokenId] = true;
    }
    function withdraw() onlyOwner public {
        uint balance = address(this).balance;
        address payable receiver = payable(msg.sender);
        receiver.transfer(balance);
    }

    /*
     * implementation details
     */
    function _baseURI() internal pure override(ERC721) returns (string memory) {
        return "https://gist.githubusercontent.com/clonker/a4c549b3d8b5733045e858abe00a7563/raw/305ad0db0ac3c28084a2cb8d36b50bf7b0adfa64/test.json";
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721, ERC721Enumerable) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || ERC721Enumerable.supportsInterface(interfaceId);
    }
}
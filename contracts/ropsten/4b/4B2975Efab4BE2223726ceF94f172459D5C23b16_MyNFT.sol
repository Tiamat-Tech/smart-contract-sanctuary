// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MyNFT is ERC721, ERC721Enumerable, Ownable {

    constructor() ERC721("MyNFT", "MNFT") {
    }

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_PUBLIC_MINT = 5;

    uint256 public constant PRICE_PUBLIC_SALE = 0.01 ether;
    uint256 public constant PRICE_PRE_SALE = 0.04 ether;
    uint256 public constant PRICE_GIVEAWAY = 0 ether;

    bool public isGiveawayActive = false;
    bool public isPresaleActive = false;
    bool public isPublicSaleActive = false;
    
    string private _baseURIextended;

    mapping(address => uint256) private _presaleAllowedList;
    mapping(address => uint256) private _giveawayAllowedList;

    function setIsGiveawayActive(bool _isGiveawayActive) external onlyOwner {
        isGiveawayActive = _isGiveawayActive;
    }
    
    function setIsPresaleActive(bool _isPresaleActive) external onlyOwner {
        isPresaleActive = _isPresaleActive;
    }
    
    function setIsPublicSaleActive(bool _isPublicSaleActive) external onlyOwner {
        isPublicSaleActive = _isPublicSaleActive;
    }

    function setGiveawayAllowedList(address[] calldata addresses, uint256 numAllowedToMint) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _giveawayAllowedList[addresses[i]] = numAllowedToMint;
        }
    }

    function setPresaleAllowedList(address[] calldata addresses, uint256 numAllowedToMint) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _presaleAllowedList[addresses[i]] = numAllowedToMint;
        }
    }

    function getGiveawayAvailableToMintByAddress(address addr) external view returns (uint256) {
        return _giveawayAllowedList[addr];
    }

    function getPresaleAvailableToMintByAddress(address addr) external view returns (uint256) {
        return _presaleAllowedList[addr];
    }

    function giveawayMint(uint256 numberOfTokens) external payable {
        uint256 currentTotalSupply = totalSupply();
        require(isGiveawayActive, "Giveaway claim is not active.");
        require(numberOfTokens <= _giveawayAllowedList[msg.sender], "No sufficient available tokens to claim.");
        require(currentTotalSupply + numberOfTokens <= MAX_SUPPLY, "This claim will exceed max possible number of tokens.");
        require(PRICE_GIVEAWAY * numberOfTokens <= msg.value, "Ether value sent is not correct/enough.");

        _giveawayAllowedList[msg.sender] -= numberOfTokens;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, currentTotalSupply + i);
        }
    }

    function presaleMint(uint256 numberOfTokens) external payable {
        uint256 currentTotalSupply = totalSupply();
        require(isPresaleActive, "Presale is not active.");
        require(numberOfTokens <= _presaleAllowedList[msg.sender], "No sufficient available tokens to purchase.");
        require(currentTotalSupply + numberOfTokens <= MAX_SUPPLY, "This purchase will exceed max possible number of tokens.");
        require(PRICE_PRE_SALE * numberOfTokens <= msg.value, "Ether value sent is not correct/enough.");

        _presaleAllowedList[msg.sender] -= numberOfTokens;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, currentTotalSupply + i);
        }
    }

    function publicSaleMint(uint numberOfTokens) public payable {
        uint256 currentTotalSupply = totalSupply();
        require(isPublicSaleActive, "Public sale is not active.");
        require(numberOfTokens <= MAX_PUBLIC_MINT, "No sufficient available tokens to purchase.");
        require(currentTotalSupply + numberOfTokens <= MAX_SUPPLY, "This purchase will exceed max possible number of tokens.");
        require(PRICE_PUBLIC_SALE * numberOfTokens <= msg.value, "Ether value sent is not correct/enough.");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, currentTotalSupply + i);
        }
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
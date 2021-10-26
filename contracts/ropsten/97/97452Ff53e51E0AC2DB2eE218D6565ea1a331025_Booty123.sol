// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

interface IKeys {
    function totalSupply() external view returns(uint256);
    function ownerOf(uint256 tokenId) external view returns(address);
} 

contract Booty123 is ERC721, ERC721Enumerable, Ownable {
    bool public saleIsActive = false;
    bool public isAllowListActive = false;
    bool public isKeyListActive = false;
    
    IKeys public Keys;
    
    string private _baseURIextended;
    mapping(address => uint8) private _allowList;

    modifier keyOwner(uint256 keyId) {
        require(Keys.ownerOf(keyId) == msg.sender, "Cannot redeem key you don't own");
        _;
    }
    // 0 = Unused
    // 1 = Used
    mapping(uint256 => uint256) public keyUsage;
    
    uint256 public constant MAX_SUPPLY = 2500;
    uint256 public constant MAX_PUBLIC_MINT = 5;
    uint256 public constant PRICE_PER_TOKEN = 0.06 ether;

    constructor() ERC721("Booty123", "BOOTY123") {
    }

    function setIsAllowListActive(bool _isAllowListActive) external onlyOwner {
        isAllowListActive = _isAllowListActive;
    }

    function setAllowList(address[] calldata addresses, uint8 numAllowedToMint) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _allowList[addresses[i]] = numAllowedToMint;
        }
    }
    
    function setIsKeyListActive(bool _isKeyListActive) external onlyOwner {
        isKeyListActive = _isKeyListActive;
    }
    
    function numAvailableToMint(address addr) external view returns (uint8) {
        return _allowList[addr];
    }

    function mintAllowList(uint8 numberOfTokens) external payable {
        uint256 ts = totalSupply();
        require(isAllowListActive, "Allow list is not active");
        require(numberOfTokens <= _allowList[msg.sender], "Exceeded max available to purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRICE_PER_TOKEN * numberOfTokens <= msg.value, "Ether value sent is not correct");

        _allowList[msg.sender] -= numberOfTokens;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    function mintWithKey(uint8 numberOfTokens, uint256 keyId) external keyOwner(keyId) {
        uint256 ts = totalSupply();
        require(isKeyListActive, "Key list is not active");
        require(keyUsage[keyId] == 0, "Key has been used");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");

        keyUsage[keyId] = 1;
        _safeMint(msg.sender, ts);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI)) : "";
    }
    
    function setKeys(address keysAddress) external onlyOwner {
        Keys = IKeys(keysAddress);
    }

    function setSaleState(bool newState) public onlyOwner {
        saleIsActive = newState;
    }

    function mintNFT(uint numberOfTokens) public payable {
        uint256 ts = totalSupply();
        require(saleIsActive, "Sale must be active to mint tokens");
        require(numberOfTokens <= MAX_PUBLIC_MINT, "Exceeded max token purchase");
        require(PRICE_PER_TOKEN * numberOfTokens <= msg.value, "Ether value sent is not correct");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}
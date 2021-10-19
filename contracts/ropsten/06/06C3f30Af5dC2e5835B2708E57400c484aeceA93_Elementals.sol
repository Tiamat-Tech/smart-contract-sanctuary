//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Elementals is ERC721Enumerable, ERC721URIStorage, Ownable {
	// private variables
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
	Counters.Counter private reservedTokenIds;
    string private baseURI;

    // public variables
    uint256 public oneElementalPrice = 0.06 ether;
    uint256 public fiveElementalsPrice = 0.25 ether;
    uint256 public tenElementalsPrice = 0.40 ether;
    uint256 public maxSupply;
    uint256 public reserved;
    uint256 public mintLimit;
    bool public presaleIsActive = false;
    bool public saleIsActive = false;
    string public elementalsProvenance;
    uint256 public revealTimestamp;
    address[] public whitelistAddresses;

    constructor(uint256 _maxSupply, uint256 _reserved, uint256 _mintLimit) ERC721("Elementals Vol. 1", "ELMTS") {
        maxSupply = _maxSupply;
        reserved = _reserved;
        mintLimit = _mintLimit;
    }

    function _mintElemental(uint256 numberElementals, address sender) internal {
        for (uint256 i; i < numberElementals; i++) {
            uint256 newItemId = tokenIds.current();
            _safeMint(sender, newItemId);
            tokenIds.increment();
        }
    }

    function mintElemental(uint256 numberElementals) public payable {
        presaleIsActive 
        ? require(isWhitelisted(msg.sender), "Wallet address not whitelisted for presale")
        : require(saleIsActive, "Public sale is not on");
        require(numberElementals < mintLimit, "Minting limited to 10 at a time");
        require(oneElementalPrice * numberElementals <= msg.value, "Incorrect eth amount sent");
        require(totalSupply() + numberElementals <= maxSupply, "Mint would exceed max supply of elementals");

        _mintElemental(numberElementals, msg.sender);
    }

    function mintFiveElementals() public payable {
        presaleIsActive 
        ? require(isWhitelisted(msg.sender), "Wallet address not whitelisted for presale")
        : require(saleIsActive, "Public sale is not on");
        require(fiveElementalsPrice <= msg.value, "Incorrect eth amount sent");
        require(totalSupply() + 5 <= maxSupply, "Mint would exceed max supply of elementals");

        _mintElemental(5, msg.sender);
    }

    function mintTenElementals() public payable {
        presaleIsActive 
        ? require(isWhitelisted(msg.sender), "Wallet address not whitelisted for presale")
        : require(saleIsActive, "Public sale is not on");
        require(tenElementalsPrice <= msg.value, "Incorrect eth amount sent");
        require(totalSupply() + 10 <= maxSupply, "Mint would exceed max supply of elementals");

        _mintElemental(10, msg.sender);
    }

    function reserve() public payable onlyOwner {
        _mintElemental(reserved, msg.sender);
    }

    function giveAway(address to, uint256 amount) public payable onlyOwner {
        uint256[] memory reserves = walletTokens(owner());
        require(amount <= reserves.length, "Giveaway exceeds reserved elementals supply");

        for (uint256 i; i < amount; i++) {
            safeTransferFrom(owner(), to, reserves[i]);
        }
    }

    function isWhitelisted(address user) internal view returns (bool) {
        for (uint256 i; i < whitelistAddresses.length; i++) {
            if (whitelistAddresses[i] == user) {
                return true;
            }
        }

        return false;
    }

    function walletTokens(address owner) public view returns (uint256[] memory) {
        uint256 totalOwned = balanceOf(owner);
        uint256[] memory ownerTokenIds = new uint256[](totalOwned);

        for (uint256 i; i < totalOwned; i++) {
            ownerTokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return ownerTokenIds;
    }

    function flipPresaleState() public onlyOwner {
        presaleIsActive = !presaleIsActive;
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function whitelistUsers(address[] calldata users) public onlyOwner {
        delete whitelistAddresses;
        whitelistAddresses = users;
    }

    function getWhitelistUsers() public view onlyOwner returns (address[] memory) {
        return whitelistAddresses;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function setRevealTimestamp(uint256 timestamp) public onlyOwner {
        revealTimestamp = timestamp;
    }

    function setProvenance(string memory provenance) public onlyOwner {
        elementalsProvenance = provenance;
    }

    function setBaseUrl(string memory baseUri) public onlyOwner {
        baseURI = baseUri;
    }

    function setTokenURI(uint256 tokenId, string memory tokenUri) public onlyOwner {
        _setTokenURI(tokenId, tokenUri);
    }

    /**
		Overload methods below
	*/

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) onlyOwner returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) onlyOwner {
        super._burn(tokenId);
    }
}
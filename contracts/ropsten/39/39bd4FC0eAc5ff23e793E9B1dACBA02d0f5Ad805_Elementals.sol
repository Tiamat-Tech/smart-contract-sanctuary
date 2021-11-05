//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Elementals is ERC721Enumerable, ERC721URIStorage, Ownable {
	// private variables
    uint256 private earthTokenId = 0;
    uint256 private waterTokenId = 2000;
    uint256 private fireTokenId = 4000;
    uint256 private windTokenId = 6000;
    uint256 private lightningTokenId = 8000;
    string private baseURI;
    string private earth = "earth";
    string private water = "water";
    string private fire = "fire";
    string private wind = "wind";
    string private lightning = "lightning";

    // public variables
    uint256 public price = 0.08 ether;
    uint256 public maxSupply = 10000;
    uint256 public mintLimit = 11;
    bool public presaleIsActive = false;
    bool public saleIsActive = false;
    string public elementalsProvenance;
    uint256 public revealTimestamp;
    address[] public whitelistAddresses;

    constructor() ERC721("Elementals Vol. 1", "ELMTS") {

    }

    modifier canMint(uint256 total) {
        presaleIsActive 
        ? require(_isWhitelisted(msg.sender), "Wallet address not whitelisted for presale")
        : require(saleIsActive, "Public sale is not on");
        require(total < mintLimit, "Minting limited to 10 at a time");
        require(msg.value >= price * total, "Incorrect eth amount sent");
        require(totalSupply() + total <= maxSupply, "Mint would exceed max supply of elementals");
        _;
    }

    function mintEarth(uint256 total) public payable canMint(total) {
        require(earthTokenId + total < 2001, "Earth Elementals Sold Out!");
        _mintEarth(total);
    }

    function mintWater(uint256 total) public payable canMint(total) {
        require(waterTokenId + total < 4001, "Water Elementals Sold Out!");
        _mintWater(total);
    }

    function mintFire(uint256 total) public payable canMint(total) {
        require(fireTokenId + total < 6001, "Fire Elementals Sold Out!");
        _mintFire(total);
    }

    function mintWind(uint256 total) public payable canMint(total) {
        require(windTokenId + total < 8001, "Wind Elementals Sold Out!");
        _mintWind(total);
    }

    function mintLightning(uint256 total) public payable canMint(total) {
        require(lightningTokenId + total < 10001, "Lightning Elementals Sold Out!");
        _mintLightning(total);
    }

    function reserve() public onlyOwner {
        _mintEarth(20);
        // _mintWater(20);
        // _mintFire(20);
        // _mintWind(20);
        // _mintLightning(20);
    }

    function getRemainingEarthCount() public view returns (uint256) {
        return 2000 - earthTokenId;
    }

    function getRemainingWaterCount() public view returns (uint256) {
        return 4000 - waterTokenId;
    }

    function getRemainingFireCount() public view returns (uint256) {
        return 6000 - fireTokenId;
    }

    function getRemainingWindCount() public view returns (uint256) {
        return 8000 - windTokenId;
    }

    function getRemainingLightningCount() public view returns (uint256) {
        return 10000 - lightningTokenId;
    }

    function giveAway(address to, uint256 amount) public payable onlyOwner {
        uint256[] memory reserves = walletTokens(owner());
        require(amount <= reserves.length, "Giveaway exceeds reserved elementals supply");

        for (uint256 i; i < amount; i++) {
            safeTransferFrom(owner(), to, reserves[i]);
        }
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
     * Internal methods 
     *
    */
    function _mintEarth(uint256 total) internal {
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, earthTokenId);
            earthTokenId += 1;
        }
    }
    
    function _mintWater(uint256 total) internal {
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, waterTokenId);
            waterTokenId += 1;
        }
    }
    
    function _mintFire(uint256 total) internal {
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, fireTokenId);
            fireTokenId += 1;
        }
    }
    
    function _mintWind(uint256 total) internal {
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, windTokenId);
            windTokenId += 1;
        }
    }
    
    function _mintLightning(uint256 total) internal {
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, lightningTokenId);
            lightningTokenId += 1;
        }
    }
    
    function _isWhitelisted(address user) internal view returns (bool) {
        for (uint256 i; i < whitelistAddresses.length; i++) {
            if (whitelistAddresses[i] == user) {
                return true;
            }
        }

        return false;
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
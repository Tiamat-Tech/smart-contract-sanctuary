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
    uint256 private earthReserves;
    uint256 private waterReserves;
    uint256 private fireReserves;    
    uint256 private windReserves;
    uint256 private lightningReserves;
    string private baseURI;

    // public variables
    uint256 public presale = 0.03 ether;
    uint256 public sale = 0.05 ether;
    uint256 public mintLimit = 11;
    uint256 public maxSupply;
    bool public presaleIsActive = false;
    bool public saleIsActive = false;
    string public elementalsProvenance;
    uint256 public revealTimestamp;
    address[] public whitelistAddresses;

    constructor(uint256 _reserved, uint256 _supply) ERC721("Elementals Vol. 1", "ELMTS") {
        earthReserves = _reserved;
        waterReserves = _reserved;
        fireReserves = _reserved;
        windReserves = _reserved;
        lightningReserves = _reserved;
        maxSupply = _supply;
    }

    modifier canMint(uint256 total) {
        require(total < mintLimit, "Minting limited to 10 at a time");

        if (presaleIsActive) {
            require(_isWhitelisted(msg.sender), "Wallet address not whitelisted for presale");
            require(msg.value >= presale * total, "Incorrect eth amount sent");
        } else {
            require(saleIsActive, "Public sale is not on");
            require(msg.value >= sale * total, "Incorrect eth amount sent");
        }
        
        require(totalSupply() + total <= maxSupply, "Mint would exceed max supply of elementals");
        _;
    }

    function mintEarth(uint256 total) public payable canMint(total) {
        require(earthTokenId < 2000 - earthReserves, "Earth Elementals Sold Out!");
        require(earthTokenId + total < 2001 - earthReserves, "Minting would exceed Earth supply!");
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, earthTokenId);
            earthTokenId += 1;
        }
    }

    function mintWater(uint256 total) public payable canMint(total) {
        require(waterTokenId < 4000 - waterReserves, "Water Elementals Sold Out!");
        require(waterTokenId + total < 4001 - waterReserves, "Minting would exceed Water supply!");
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, waterTokenId);
            waterTokenId += 1;
        }
    }

    function mintFire(uint256 total) public payable canMint(total) {
        require(fireTokenId < 6000 - fireReserves, "Fire Elementals Sold Out!");
        require(fireTokenId + total < 6001 - fireReserves, "Minting would exceed Fire supply!");
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, fireTokenId);
            fireTokenId += 1;
        }
    }

    function mintWind(uint256 total) public payable canMint(total) {
        require(windTokenId < 8000 - windReserves, "Wind Elementals Sold Out!");
        require(windTokenId + total < 8001 - windReserves, "Minting would exceed Wind supply!");
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, windTokenId);
            windTokenId += 1;
        }
    }

    function mintLightning(uint256 total) public payable canMint(total) {
        require(lightningTokenId < 10000 - lightningReserves, "Lightning Elementals Sold Out!");
        require(lightningTokenId + total < 10001 - lightningReserves, "Minting would exceed Lightning supply!");
        for (uint256 i; i < total; i++) {
            _safeMint(msg.sender, lightningTokenId);
            lightningTokenId += 1;
        }
    }

    function getRemainingElementals() external view returns (uint256[] memory) {
        uint256[] memory counts = new uint256[](5);
        counts[0] = 2000 - earthReserves - earthTokenId;
        counts[1] = 4000 - waterReserves - waterTokenId;
        counts[2] = 6000 - fireReserves - fireTokenId;
        counts[3] = 8000 - windReserves - windTokenId;
        counts[4] = 10000 - lightningReserves - lightningTokenId;
        return counts;
    }

    function earthGiveaway(address to, uint256 amount) external onlyOwner {
        require(amount < earthReserves + 1, "Giveaway exceeds reserved earth elementals supply");

        for (uint256 i; i < amount; i++) {
            _safeMint(to, earthTokenId);
            earthTokenId = earthTokenId + 1;
        }

        earthReserves = earthReserves - amount;
    }

    function waterGiveaway(address to, uint256 amount) external onlyOwner {
        require(amount < waterReserves + 1, "Giveaway exceeds reserved water elementals supply");

        for (uint256 i; i < amount; i++) {
            _safeMint(to, waterTokenId);
            waterTokenId = waterTokenId + 1;
        }

        waterReserves = waterReserves - amount;
    }

    function fireGiveaway(address to, uint256 amount) external onlyOwner {
        require(amount < fireReserves + 1, "Giveaway exceeds reserved fire elementals supply");

        for (uint256 i; i < amount; i++) {
            _safeMint(to, fireTokenId);
            fireTokenId = fireTokenId + 1;
        }

        fireReserves = fireReserves - amount;
    }

    function windGiveaway(address to, uint256 amount) external onlyOwner {
        require(amount < windReserves + 1, "Giveaway exceeds reserved wind elementals supply");

        for (uint256 i; i < amount; i++) {
            _safeMint(to, windTokenId);
            windTokenId = windTokenId + 1;
        }

        windReserves = windReserves - amount;
    }

    function lightningGiveaway(address to, uint256 amount) external onlyOwner {
        require(amount < lightningReserves + 1, "Giveaway exceeds reserved lightning elementals supply");

        for (uint256 i; i < amount; i++) {
            _safeMint(to, lightningTokenId);
            lightningTokenId = lightningTokenId + 1;
        }

        lightningReserves = lightningReserves - amount;
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

    function setBaseUrl(string memory baseUri) public onlyOwner {
        baseURI = baseUri;
    }

    function setTokenURI(uint256 tokenId, string memory tokenUri) public onlyOwner {
        _setTokenURI(tokenId, tokenUri);
    }

    function setProvenance(string memory provenance) external onlyOwner {
        elementalsProvenance = provenance;
    }

    function setReveal(uint256 reveal) external onlyOwner {
        revealTimestamp = reveal;
    }

    function setPresale(uint256 price) external onlyOwner {
        presale = price;
    }

    function setSale(uint256 price) external onlyOwner {
        sale = price;
    }
    
    /**
     * Internal methods 
     *
    */
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
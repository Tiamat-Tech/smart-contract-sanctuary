// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract Chibis is ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using StringsUpgradeable for uint256;
    event Minted(address indexed sender, uint256 minted, uint mintedFaction, uint256 times);

    mapping(uint256 => uint256) public factionPrice; 
    mapping(uint256 => uint256) public factionTotal; 
    mapping(uint256 => uint256) public factionMinted; 
    mapping(uint256 => uint256) public tokenFactions;

    uint256 public totalMinted;
    uint256 public totalFactions;
    string public baseURI;

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseURI_,
        uint256 factions,
        uint256 price,
        uint256 total,
        address admin
    ) initializer public {
        require(factions > 0);
        
        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __Ownable_init_unchained();
        setBaseURI(baseURI_);
        transferOwnership(admin);

        totalFactions = factions;
        for (uint256 i; i < factions; ++i) {
            factionPrice[i + 1] = price;
            factionTotal[i + 1] = total;
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newURI) public onlyOwner {
        baseURI = _newURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token.");
        
        string memory baseURI_ = _baseURI();

        return bytes(baseURI_).length > 0
            ? string(abi.encodePacked(baseURI_, tokenFactions[tokenId], "/", tokenId.toString(), ".json")) : ".json";
    }

    function tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 count = balanceOf(owner);
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = tokenOfOwnerByIndex(owner, i);
        }
        return ids;
    }

    function addFactions(uint256 amount, uint256 price, uint256 total) public onlyOwner {
        require(amount > 0 && amount <= 10, "Amount must be 1-10 or less");
        totalFactions += amount;
        for (uint256 i; i < amount; ++i) {
            factionPrice[totalFactions - i] = price;
            factionTotal[totalFactions - i] = total;
        }
    }

    function setFactionTotal(uint256 faction, uint256 total) public onlyOwner {
        factionTotal[faction] = total;
    }

    function setFactionPrice(uint256 faction, uint256 price) public onlyOwner {
        factionPrice[faction] = price;
    }
    
    function mint(uint256 faction, uint256 times) payable public {
        require(faction > 0 && faction <= totalFactions, "Faction doesn't exist.");
        require(times > 0 && times <= 10, "Can't mint this many at once.");
        require(factionMinted[faction] + times <= factionTotal[faction], "Exceeds minting limit.");
        require(msg.value >= times * factionPrice[faction], "Value error, please check price.");
        payable(owner()).transfer(msg.value);
        emit Minted(_msgSender(), totalMinted + 1, factionMinted[faction] + 1, times);
        factionMinted[faction] += times;
        for (uint256 i = 0; i < times; i++) {
            tokenFactions[faction] = totalMinted + 1;
            _mint(_msgSender(), 1 + totalMinted++);
        }
    }  
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// import "./ERC721Pausable.sol";
// contract FishMenu is ERC721Enumerable, Ownable, ERC721Burnable, ERC721Pausable {
contract FishMenu is ERC721Enumerable, Ownable, ERC721Burnable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // Counters.Counter private _tokenIdTracker;

    struct MenuSection { 
        string title;
        uint256 MAX_SUPPLY;
        uint256 MAX_PER_MINT;
        uint256 price; // TODO: Set price function?
        uint256 TEAM_RESERVE; // TODO: set team reserv function?
        bool saleActive;
    }

    // uint256 private constant MAX_SUPPLY = 8888;
    uint256 private constant MAX_MENU_SECTIONS = 4;
    uint256 private constant PRICE = 3 * 10**16;
    uint256 private constant MAX_PER_MINT = 5;
    mapping(uint => MenuSection) public menuSections;
    uint public currentMenuSection = 0;

    address public constant creatorAddress = 0x6F84Fa72Ca4554E0eEFcB9032e5A4F1FB41b726C;
    address public constant devAddress = 0xcBCc84766F2950CF867f42D766c43fB2D2Ba3256;

    string public baseTokenURI;
    // bool public pauseLocked = false;

    event CreateFish(uint256 indexed id);
    constructor() ERC721("FishMenu", "FM") {
        _mapMenuSection(0, MenuSection("Starters", 2222, MAX_PER_MINT, PRICE, 20, false));
        _mapMenuSection(1, MenuSection("Mains", 3333, MAX_PER_MINT, PRICE, 60, false));
        _mapMenuSection(2, MenuSection("Specials", 1111, MAX_PER_MINT, PRICE, 20, false));
        _mapMenuSection(3, MenuSection("Dessert", 2222, MAX_PER_MINT, PRICE, 40, false));
        // pause(true);
    }

    function _mapMenuSection(
        uint256 key,
        MenuSection memory value
        // string title,
        // uint256 id,
        // uint256 maxSupply,
        // uint256 maxPerMint,
        // uint256 price, // TODO: Set price function?
        // uint256 teamReserve, // TODO: set team reserv function?
        // bool paused
    ) private {
        // MenuSection menuSections[key]
        // campaignID = numCampaigns++; // campaignID is return variable
        // We cannot use "campaigns[campaignID] = Campaign(beneficiary, goal, 0, 0)"
        // because the RHS creates a memory-struct "Campaign" that contains a mapping.
        MenuSection storage menuSection = menuSections[key];
        menuSection.title = value.title;
        menuSection.MAX_SUPPLY = value.MAX_SUPPLY;
        menuSection.MAX_PER_MINT = value.MAX_PER_MINT;
        menuSection.price = value.price; // TODO: Set price function?
        menuSection.TEAM_RESERVE = value.TEAM_RESERVE; // TODO: set team reserv function?
        menuSection.saleActive = value.saleActive;
    }

    function setNextMenuSection(uint sectionKey) public onlyOwner {
        require(sectionKey < MAX_MENU_SECTIONS, "This is the last section");
        require(totalSupply() >= menuSections[currentMenuSection].MAX_SUPPLY, "Current section is not sold out");
        currentMenuSection = sectionKey;
    }

    function startSale() public onlyOwner {
        require(!menuSections[currentMenuSection].saleActive, "Sale already active");
        // require(totalSupply() >= menuSections[currentMenuSection].MAX_SUPPLY, "Current section is not sold out");
        MenuSection storage menuSection = menuSections[currentMenuSection];
        menuSection.saleActive = true;
    }

    // function maxSupply() public view returns (uint256) {
    //     // if maxSupplyLocked return 
    //     // else return MAX_SUPPLY
    // }

    // function _totalSupply() internal view returns (uint) {
    //     return _tokenIdTracker.current();
    // }

    // function totalMint() public view returns (uint256) {
    //     return _totalSupply();
    // }

    function mint(address _to, uint256 _count) public payable {
        MenuSection storage menuSection = menuSections[currentMenuSection];
        require(menuSection.saleActive, "Sale not started");
        // uint256 total = _totalSupply();
        uint256 total = totalSupply();
        require(total <= menuSection.MAX_SUPPLY, "Sale end");
        require(total + _count <= menuSection.MAX_SUPPLY, "Exceeds max supply");
        require(_count <= menuSection.MAX_PER_MINT, "Exceeds max tokens per mint");
        require(msg.value >= price(_count), "Value below price");

        for (uint256 i = 0; i < _count; i++) {
            _mintFish(_to);
        }
    }

    function reserve(uint256 _count) public onlyOwner {
        MenuSection storage menuSection = menuSections[currentMenuSection];
        // uint256 total = _totalSupply();
        uint256 total = totalSupply();
        require(total + _count <= menuSection.MAX_SUPPLY, "Exceeds max supply");
        require(_count <= menuSection.TEAM_RESERVE, "Exceeds reserve");

        for (uint256 i = 0; i < _count; i++) {
            _mintFish(devAddress);
        }
    }

    function _mintFish(address _to) private {
        // uint id = _totalSupply();
        uint id = totalSupply();
        // _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateFish(id);
    }

    function price(uint256 _count) public pure returns (uint256) {
        return PRICE.mul(_count);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    // function pause(bool val) public onlyOwner {
    //     require(!pauseLocked, "Pause is locked");
    //     if (val == true) {
    //         _pause();
    //         return;
    //     }
    //     _unpause();
    // }

    // function lockPause() public onlyOwner {
    //     require(!pauseLocked, "Pause is locked");
    //     _unpause();
    //     pauseLocked = true;
    // }

    function withdrawAll() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _widthdraw(devAddress, balance.mul(50).div(100));
        _widthdraw(creatorAddress, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    // ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
}
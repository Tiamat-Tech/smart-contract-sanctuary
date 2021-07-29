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
        bool initialized;
        bool saleActive;
        uint maxSupply;
        uint maxMintPerTransaction;
        uint teamReserve;
        uint256 price;
    }

    mapping(uint => MenuSection) public menuSections;
    uint public currentMenuSection = 0;
    bool public menuSectionsLocked = false;

    uint256 public constant HARD_CAP = 8888;
    uint256 private constant PRICE = 3 * 10**16;
    uint256 private constant MAX_MINT_PER_TRANSACTION = 5;

    address public constant creatorAddress = 0x6F84Fa72Ca4554E0eEFcB9032e5A4F1FB41b726C;
    address public constant devAddress = 0xcBCc84766F2950CF867f42D766c43fB2D2Ba3256;

    string private baseTokenURI;
    // bool public pauseLocked = false;

    event CreateFish(uint indexed id);
    constructor() ERC721("FishMenu", "Fish") {
        addMenuSection(0, "Starters", true, false, 22, MAX_MINT_PER_TRANSACTION, PRICE, 20);
        addMenuSection(1, "Mains", true, false, 33, MAX_MINT_PER_TRANSACTION, PRICE, 60);
        // pause(true);
    }

    function addMenuSection(
        uint _key,
        string memory _title,
        bool _initialized,
        bool _saleActive,
        uint _maxSupply,
        uint _maxMintPerTransaction,
        uint _teamReserve,
        uint256 _price
    ) public onlyOwner {
        require(!menuSectionsLocked, "Can't add more sections");
        require(maxSupply() + _maxSupply - menuSections[_key].maxSupply <= HARD_CAP, "");

        MenuSection storage menuSection = menuSections[_key];
        menuSection.title = _title;
        menuSection.initialized = _initialized;
        menuSection.saleActive = _saleActive;
        menuSection.maxSupply = _maxSupply;
        menuSection.maxMintPerTransaction = _maxMintPerTransaction;
        menuSection.teamReserve = _teamReserve; 
        menuSection.price = _price;
        // _addMenuSection(_key, MenuSection(_title, false, true, _maxSupply, _maxMintPerTransaction, _teamReserve, _price));
    }

    // function _addMenuSection(uint _key, MenuSection memory _value) private {
    //     MenuSection storage menuSection = menuSections[_key];
    //     require(maxSupply() + _value.maxSupply - menuSection.maxSupply <= HARD_CAP, "");

    //     menuSection.title = _value.title;
    //     menuSection.initialized = _value.initialized;
    //     menuSection.saleActive = _value.saleActive;
    //     menuSection.maxSupply = _value.maxSupply;
    //     menuSection.maxMintPerTransaction = _value.maxMintPerTransaction;
    //     menuSection.teamReserve = _value.teamReserve; 
    //     menuSection.price = _value.price;
    // }

    function lockMenuSections() public onlyOwner {
        require(!menuSectionsLocked, "Already locked");
        menuSectionsLocked = true;
    }

    function setMenuSection(uint _sectionKey) public onlyOwner {
        require(menuSections[_sectionKey].initialized, "Section does not exist");
        require(totalSupply() >= menuSections[currentMenuSection].maxSupply, "Current section is not sold out");
        currentMenuSection = _sectionKey;
    }

    function startSale() public onlyOwner {
        require(!menuSections[currentMenuSection].saleActive, "Sale already active");
        MenuSection storage menuSection = menuSections[currentMenuSection];
        menuSection.saleActive = true;
    }

    function maxSupply() public view returns (uint) {
        uint _maxSupply = 0;
        for (uint i = 0; i <= currentMenuSection; i++) {
            _maxSupply += menuSections[i].maxSupply;
        }

        return _maxSupply;
    }

    // function _totalSupply() internal view returns (uint) {
    //     return _tokenIdTracker.current();
    // }

    // function totalMint() public view returns (uint256) {
    //     return _totalSupply();
    // }

    function mint(address _to, uint _count) public payable {
        MenuSection storage menuSection = menuSections[currentMenuSection];
        require(menuSection.saleActive, "Sale not started");
        // uint256 total = _totalSupply();
        uint256 total = totalSupply();
        require(total <= menuSection.maxSupply, "Sale end");
        require(total + _count <= menuSection.maxSupply, "Exceeds max supply");
        require(_count <= menuSection.maxMintPerTransaction, "Exceeds max tokens per mint");
        require(msg.value >= price(_count), "Value below price");

        for (uint i = 0; i < _count; i++) {
            _mintFish(_to);
        }
    }

    function reserve(address _to, uint _count) public onlyOwner {
        MenuSection storage menuSection = menuSections[currentMenuSection];
        // uint256 total = _totalSupply();
        uint256 total = totalSupply();
        require(total + _count <= menuSection.maxSupply, "Exceeds max supply");
        require(_count <= menuSection.teamReserve, "Exceeds reserve");

        for (uint i = 0; i < _count; i++) {
            _mintFish(_to);
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

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
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
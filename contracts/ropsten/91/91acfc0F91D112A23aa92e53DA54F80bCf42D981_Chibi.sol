// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Chibi is ERC721Enumerable, Ownable {
    uint256 public constant TOTAL_CHIBI_AMOUNT = 5555;
    uint256 public constant MAX_PURCHASE = 10;
    uint256 public price = 55000000000000000;

    bool public isSaleOpen = false;
    string internal _baseTokenURI;

    using Strings for uint256;

    constructor(string memory baseURI) ERC721("chibilegends", "Chibi")  {
        changeBaseURI(baseURI);
    }

    /**
     **  Modifiers
     */ 
    modifier mintingIsAvailable{
        require(totalSupply() < TOTAL_CHIBI_AMOUNT, "No Chibi left to mint.");
        _;
    }

    /**
     **  onlyOwner functions
     */     
    function getBaseURI() public onlyOwner view returns (string memory) {
        return _baseURI();
    }

    function changeBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function changePrice(uint _price) public onlyOwner {
        price = _price;
    }

    function changeSaleOpen(bool _open) public onlyOwner {
        isSaleOpen = _open;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(_msgSender()).send(address(this).balance));
    }

    /**
     **  Public functions
     */ 
    function mintChibi(uint256 qty) public payable mintingIsAvailable {
        if(msg.sender != owner()){
            require(isSaleOpen, "Sale is not open.");
        }
        require(totalSupply() < TOTAL_CHIBI_AMOUNT, "All Chibis are minted.");
        require(qty <= MAX_PURCHASE, "Buying too many per transaction.");
        require(SafeMath.add(totalSupply(), qty) <= TOTAL_CHIBI_AMOUNT, "Going over 5555 chibi with the purchase.");
        require(msg.value >= _getPrice(qty), "Invalid price.");

        for(uint256 i = 0; i < qty; i++) {
            _safeMint(msg.sender, totalSupply());
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, "/", tokenId.toString(), ".json")) : "";
    }

    /**
     **  Internal functions
     */ 
    function _getPrice(uint256 qty) internal view returns (uint256) {
        return price * qty;
    }
}
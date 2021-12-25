//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Templated is ERC721Enumerable, Ownable {
    string private _baseTokenURI;
    uint256 private _maxSupply = 10000;
    uint256 private _price = 0.04 ether;
    uint256 public _presaleLimit = 10;
    uint256 public _reserved = 500;
    bool private _preSaleActive = false;
    bool private _mainSaleActive = false;

    constructor() ERC721("Templated", "TMPLC") {}

    mapping(address => bool) private _inPresale;
    mapping(address => uint256) private _totalClaimed;

    function addToPresale(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Cannot add null address");

            _inPresale[addresses[i]] = true;
            _totalClaimed[addresses[i]] > 0 ? _totalClaimed[addresses[i]] : 0;
        }
    }

    function mintPresale(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(_preSaleActive, "Presale has not started");
        require(_inPresale[msg.sender], "You are not eligible for the presale");
        require(
            _reserved + supply + num <= _maxSupply,
            "No more NFT's available for mint"
        );
        require(
            _totalClaimed[msg.sender] + num <= _presaleLimit,
            "Not enough available to mint during presale"
        );
        require(
            msg.value >= _price * num,
            "Please send correct amount of ether"
        );

        for (uint256 i = 0; i < num; i++) {
            _totalClaimed[msg.sender] += 1;
            _safeMint(msg.sender, supply + i + 1);
        }
    }

    function mintMainSale(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(_mainSaleActive, "Main Sale is not available yet");
        require(num > 0 && num < 21, "Only 1 to 20 mints per transaction");
        require(
            _reserved + supply + num <= _maxSupply,
            "No more available to mint"
        );
        require(
            msg.value >= _price * num,
            "Please send correct amount of ether"
        );

        for (uint256 i = 0; i < num; i++) {
            _safeMint(msg.sender, supply + i + 1);
        }
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function setPrice(uint256 _newPrice) public onlyOwner {
        _price = _newPrice;
    }

    function inPresale(address addr) external view returns (bool) {
        return _inPresale[addr];
    }

    function resumePresale() public onlyOwner {
        _preSaleActive = true;
    }

    function resumeMainSale() public onlyOwner {
        _mainSaleActive = true;
    }

    function pausePresale() public onlyOwner {
        _preSaleActive = false;
    }

    function pauseMainSale() public onlyOwner {
        _mainSaleActive = false;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        _baseTokenURI = string(uri);
    }

    function getPrice() public view returns (uint256) {
        return _price;
    }

    function getBaseTokenURI() public view onlyOwner returns (string memory) {
        return _baseTokenURI;
    }

    function getTokensLeft() public view returns (uint256) {
        uint256 supply = totalSupply();
        return _maxSupply - supply - _reserved;
    }

    function giveAway(address to, uint256 quantity) external onlyOwner {
        uint256 supply = totalSupply();
        require(quantity <= _reserved, "Exceeds NFT minting limit");

        _reserved -= quantity;
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(to, supply + i + 1);
        }
    }

    function withdrawAll() public payable onlyOwner {}
}
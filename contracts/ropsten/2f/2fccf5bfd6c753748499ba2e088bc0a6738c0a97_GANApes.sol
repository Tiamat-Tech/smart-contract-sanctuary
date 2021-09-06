// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;


import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract GANApes is ERC721Enumerable, Ownable {
    uint256 public constant maxApes = 10000;
    uint256 private constant RESERVED_SUPPLY = 32;
    uint256 public constant maxBatch = 20;
    string private _baseUriString;
    uint256 public price = 4 * 1e7 gwei; // 0.04 ETH

    uint256 public saleStart = 1632146400; // Monday, September 20, 2021 2:00:00 PM
    bool public isStarted = false;

    constructor() ERC721('Acid GAN Apes', 'AGANA') {
        _baseUriString = 'http://acidganapes.local/';

        for (uint256 i; i < RESERVED_SUPPLY; i++) {
            uint256 mintIndex = i + 1;
            _mint(owner(), mintIndex);
        }
    }

    modifier mintStarted() {
        require(block.timestamp >= saleStart, 'Sale not started');
        require(isStarted, 'Sale not started');
        _;
    }

    function mint(uint256 quantity) public payable mintStarted {
        require(quantity > 0 && quantity <= maxBatch, 'Quantity must be 0 < x <= 20');
        require((totalSupply() + quantity) <= maxApes, 'Not enough apes');

        uint256 totalCost = quantity * price;
        require(msg.value >= totalCost, 'Insufficient ETH');
        payable(owner()).transfer(msg.value);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 mintIndex = totalSupply() + 1;
            _mint(_msgSender(), mintIndex);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseUriString;
    }

    // Admin functions
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseUriString = baseURI_;
    }

    function setPrice(uint256 price_) external onlyOwner {
        price = price_;
    }

    function setSaleStart(uint256 saleStart_) external onlyOwner {
        saleStart = saleStart_;
    }

    function setIsStarted(bool isStarted_) external onlyOwner {
        isStarted = isStarted_;
    }
}
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;


import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract LooptribeNFT is ERC721Enumerable, Ownable {
    uint256 public constant maxSupply = 50;
    string public baseUri;
    uint256 public price = 1 * 1e6 gwei; // 0.001 ETH

    constructor() ERC721('Looptribe NFT', 'LNFT') {
        baseUri = 'https://web3-serverlessdays-nft.s3.amazonaws.com/metadata/';
    }

    function mint(uint256 quantity) external payable {
        require((totalSupply() + quantity) <= maxSupply, 'Not enough supply');

        uint256 totalCost = quantity * price;
        require(msg.value >= totalCost, 'Insufficient ETH');
        payable(owner()).transfer(msg.value);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 mintIndex = totalSupply() + 1;
            _mint(_msgSender(), mintIndex);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    // Admin functions
    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseUri = baseURI_;
    }

    function setPrice(uint256 price_) external onlyOwner {
        price = price_;
    }
}
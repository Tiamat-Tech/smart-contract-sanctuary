//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SimpleNFT is ERC721 {
    uint256 private constant TOTAL_SUPPLY = 5;
    uint256 private constant PRICE_INCREMENT_STEP = 0.01 ether;

    uint256 public price = PRICE_INCREMENT_STEP;
    uint256 public nextTokenId;

    constructor() ERC721("SimpleNFT", "SNFT") {}

    /**
     * @dev mint the next NFT, price increment 1 from the last mint
     */
    function mint(address _to) external payable {
        require(msg.value >= price, "Not enough ETH");
        require(nextTokenId < TOTAL_SUPPLY, "Reached max supply");
        _safeMint(_to, nextTokenId);
        price += PRICE_INCREMENT_STEP;
        nextTokenId++;
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lofity is ERC721Enumerable, Ownable {
    uint256 public constant SALE_PRICE = 0.01 ether;
    uint256 public constant MAX_SUPPLY = 10000;

    constructor() ERC721("Lofity", "LOFI") {}

    function buy(address to, uint256 num) external payable {
        require(msg.value * num == SALE_PRICE, "Send incorrect amount of ether.");
        require(totalSupply() + num < MAX_SUPPLY, "Exceed max supply.");
        for (uint256 i = 0; i < num; i++) {
            _safeMint(to, totalSupply());
        }
    }

    function freeMintByOwner(address to, uint256 num) external onlyOwner {
        require(totalSupply() + num < MAX_SUPPLY, "Exceed max supply.");
        for (uint256 i = 0; i < num; i++) {
            _safeMint(to, totalSupply());
        }
    }
}
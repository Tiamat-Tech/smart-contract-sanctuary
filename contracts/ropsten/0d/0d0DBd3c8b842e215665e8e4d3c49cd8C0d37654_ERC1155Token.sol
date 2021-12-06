// 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ERC1155Token is ERC1155 {
     uint256 public constant GOLD = 146321417776003539289251081195660330926080;
    uint256 public constant SILVER = 1;
     uint256 public constant BRONZE = 2;

    constructor() public ERC1155("abc") {
            _mint(msg.sender, GOLD, 10**18, "");
            _mint(msg.sender, SILVER, 100, "");
            _mint(msg.sender, BRONZE, 1, "");
    }
}
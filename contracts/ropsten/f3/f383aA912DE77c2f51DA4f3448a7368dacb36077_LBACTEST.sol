pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract LBACTEST is ERC721Enumerable, Ownable {

    uint256 public constant MAX_SUPPLY = 5000;

    constructor() ERC721("TEST", "TEST") {}

    function mint(uint256 numberOfTokens) public {
        require(numberOfTokens > 0, "invalid amount");
        require(totalSupply() + numberOfTokens <= MAX_SUPPLY, "exceeds supply");

        for (uint i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, totalSupply());
        }
    }
}
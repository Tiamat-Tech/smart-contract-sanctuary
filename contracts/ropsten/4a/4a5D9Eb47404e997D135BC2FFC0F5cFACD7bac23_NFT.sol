// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";

contract NFT is ERC721, PullPayment {
    using Counters for Counters.Counter;

// Constants
  uint256 public constant TOTAL_SUPPLY = 8_888;
  uint256 public constant MINT_PRICE = 0.1 ether;

    Counters.Counter private currentTokenId;
    
  /// @dev Base token URI used as a prefix by tokenURI().
  string public baseTokenURI;

    constructor() ERC721("TestNFT", "DDD") {
        baseTokenURI = "";
    }
    
    function mintTo(address recipient) public payable returns (uint256)
    {
        uint256 tokenId = currentTokenId.current();
        require(tokenId < TOTAL_SUPPLY, "Max supply reached");
        require(msg.value == MINT_PRICE, "Transaction value did not equal the mint price");

        currentTokenId.increment();
        uint256 newItemId = currentTokenId.current();
        _safeMint(recipient, newItemId);
        return newItemId;
    }

    /// @dev Returns an URI for a given token ID
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /// @dev Sets the base token URI prefix.
    function setBaseTokenURI(string memory _baseTokenURI) public {
        baseTokenURI = _baseTokenURI;
    }
}
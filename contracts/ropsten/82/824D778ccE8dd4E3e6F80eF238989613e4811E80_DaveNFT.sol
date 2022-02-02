//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract DaveNFT is ERC721URIStorage, PullPayment, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    // Constants
    uint256 public constant TOTAL_SUPPLY = 10_000;
    uint256 public constant MINT_PRICE = 0.08 ether;

    
    constructor() ERC721("DaveNFT", "DAVE") {}

    function mintNFT(address recipient, string memory tokenURI) public payable returns (uint256)
    {
        uint256 tokenId = _tokenIds.current();
        require(tokenId < TOTAL_SUPPLY, "Max supply reached");
        require(msg.value >= MINT_PRICE, "Transaction value did not equal the mint price");

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        
        return newItemId;
    }

    /// @dev Overridden in order to make it an onlyOwner function
    function withdrawPayments(address payable payee) public override onlyOwner virtual {
        super.withdrawPayments(payee);
    }

}
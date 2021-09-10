//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Wassilikes is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    uint256 public constant PUBLIC_MINT_PRICE = 40000000000000000; // 0.04 ETH
    uint256 private constant MAX_MINTABLE_TOKENS = 1;    

    constructor() public ERC721("Wassilikes v0.1.0", "WASSI") {}

    function claim(address recipient, string memory tokenURI)
        public
        payable
        returns (uint256)
    {
        // Require that the user sends no more or less than the mint price
        require(msg.value == PUBLIC_MINT_PRICE);
        // Get the current next tokenID
        uint256 nextId = _tokenIdCounter.current();
        require(nextId < MAX_MINTABLE_TOKENS, "Token limit reached");

        //Mint the token and set URI
        _safeMint(recipient, nextId);
        _setTokenURI(nextId, tokenURI);

        //Increment the tokenIdCounter in order to
        //setup the next mint
        _tokenIdCounter.increment();

        // Provide new tokenId back to the caller
        return nextId;
    } 

    // Owner can claim the final token from the series
    function ownerClaim() public onlyOwner {
        require(_tokenIdCounter.current() == 1, "Token ID invalid");
        _safeMint(owner(), _tokenIdCounter.current());
    }

    function getPrice() 
        public
        view
        returns (uint256) 
    {
        return PUBLIC_MINT_PRICE;
    }
}
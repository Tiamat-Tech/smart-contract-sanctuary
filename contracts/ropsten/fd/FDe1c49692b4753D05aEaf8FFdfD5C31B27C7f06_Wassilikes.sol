//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Wassilikes is Ownable, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // Constants are set to public so we don't waste gas uploading getters
    uint256 public constant PUBLIC_MINT_PRICE = 40000000000000000; // 0.04 ETH
    uint256 public constant MAX_MINTABLE_TOKENS = 2;    
    address payable[1] royaltyRecipients;

    string public _prefixURI;
    string private baseURI;

    constructor(
        string memory initialBaseURI,
        address payable[1] memory _royaltyRecipients
    ) public ERC721("Wassilikes v0.1.1", "WASSI") {
        require(_royaltyRecipients[0] != address(0), "Invalid address");  

        baseURI = initialBaseURI;   
        royaltyRecipients = _royaltyRecipients;  
    }

    // #region Minting Functions
    function claim(address recipient)
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

        //Increment the tokenIdCounter in order to
        //setup the next mint
        _tokenIdCounter.increment();

        // Provide new tokenId back to the caller
        return nextId;
    } 

    // Owner can claim the final token from the series
    function ownerClaim() public onlyOwner {
        require(_tokenIdCounter.current() == 2, "Token ID invalid");
        _safeMint(owner(), _tokenIdCounter.current());
    }

    //#regionEnd Minting Functions

    // #region URI Functions

    //Allow the URI to be changed after mint
    //We should provide permanence at some point
    function setBaseURI(string memory _uri) public onlyOwner {
        _prefixURI = _uri;
    }
    
    // Overried the baseURI call so we can use our prefix instead
    function _baseURI() internal view override returns (string memory) {
        return _prefixURI;
    }

    function _tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        // if (metadataIndex == 0) {
        //     return string(abi.encodePacked(baseURI, "unrevealed.json"));
        // }

        //uint256 metadataId = (tokenId + metadataIndex) % MAX_MINTABLE_TOKENS;
        return string(abi.encodePacked(baseURI, tokenId, ".json"));
    }

    //#regionEnd URI Functions

    //#region Ether Functions
    function withdrawETH() public onlyOwner  {
        uint256 royalty = address(this).balance;

        Address.sendValue(payable(royaltyRecipients[0]), royalty);
        //Address.sendValue(payable(royaltyRecipients[1]), royalty);
    }
    //#regionEnd URI Functions
}
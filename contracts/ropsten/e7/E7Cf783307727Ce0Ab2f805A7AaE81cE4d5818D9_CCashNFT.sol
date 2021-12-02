//SPDX-License-Identifier: MIT
pragma solidity >=0.7.3;

// implements the ERC721 standard
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// keeps track of the number of tokens issued
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


//https://docs.openzeppelin.com/contracts/4.x/erc721
// Accessing the Ownable method ensures that only the creator of the smart contract can interact with it
contract CCashNFT is ERC721, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // the name and symbol for the NFT
    constructor() ERC721("CCashNFT", "CCN") {
    }

    // Create a function to mint/create the NFT
    // recipient takes a type of address. This is the wallet address of the user that should receive the NFT minted using the smart contract
    // tokenURI takes a string that contains metadata about the NFT
    function mintNFT(address recipient, string memory tokenURI) public onlyOwner returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        // returns the id for the newly created token
        return newItemId;
    }

}
//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.3;

import "hardhat/console.sol";

// implements the ERC721 standard
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// keeps track of the number of tokens issued
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/*
// implements the ERC721 standard
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC721/ERC721.sol";
//https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol


// keeps track of the number of tokens issued
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/Counters.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/utils/Pausable.sol";

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/IERC20.sol";
*/

contract RankingNFT is ERC721, Ownable, Pausable {

    event OnMintNFT(address indexed _recipient, string indexed _tokenURI, uint256 indexed _newItemId);

    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    // the name and symbol for the NFT
    constructor() ERC721("RankingNFT", "RANKNFT") {
    }

    // Create a function to mint/create the NFT
    // recipient takes a type of address. This is the wallet address of the user that should receive the NFT minted using the smart contract
    // tokenURI takes a string that contains metadata about the NFT
    function mintNFT(address _recipient, string memory _tokenURI) public onlyOwner returns (uint256) {

        console.log("mintNFT, Sender=%s, _recipient=%s, _tokenURI=%s", msg.sender, _recipient, _tokenURI);

        tokenIds.increment();

        uint256 newItemId = tokenIds.current();
        console.log("mintNFT, newItemId=%s", newItemId);
        
        _mint(_recipient, newItemId);
        _setTokenURI(newItemId, _tokenURI);

        emit OnMintNFT(_recipient, _tokenURI, newItemId);

        // returns the id for the newly created token
        return newItemId;
    }
}
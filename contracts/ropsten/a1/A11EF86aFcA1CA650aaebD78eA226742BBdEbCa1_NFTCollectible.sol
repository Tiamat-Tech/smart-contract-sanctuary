//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFTCollectible is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;
    uint public constant MAX_SUPPLY = 10000;
    uint public constant PRICE = 0.01 ether;
    uint public constant MAX_PER_MINT = 5;

    string public baseTokenURI;

    constructor(string memory baseURI) ERC721("Chalksy", "NFTC") {
        setBaseURI(baseURI);
    }

    
    ///@dev Privileged function to mint 10 NFTS 
    function reserveNFTs() public onlyOwner {
        uint totalMinted = _tokenIds.current();

        require(totalMinted.add(10) <= MAX_SUPPLY, "Not enough tokens left to be minted");
        
        for(uint i = 0; i < 10; i++) {
            _mintSingleNFT();
        }
    } 

    ///@dev Returns the URI for token data 
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    ///@dev Sets the URI for token data 
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    ///@dev This function mints the NFT for the user
    ///@param _count: number of NFTs user wants to mint 
    function mintNFTs(uint _count) public payable {
        uint totalMinted = _tokenIds.current();
        
        require(totalMinted.add(_count) <= MAX_SUPPLY, "Not enough tokens left to be minted!");

        require(_count > 0 && _count <= MAX_PER_MINT, "Invalid numbers of NFT to be minted");

        require(msg.value >= PRICE.mul(_count), "Sorry pal you're gonna need some more money for these candy bars");

        for(uint i = 0; i < _count; i++) {
            _mintSingleNFT();
        }
    }

    ///@dev Internal function for minting a single NFT
    // private function can be called by contracts that inherit from this contract
    function _mintSingleNFT() private {
        uint newTokenID = _tokenIds.current();
        // safeMint is an openZeppelin function that assigns the newTokenId to the address of the minter (msg.sender)
        _safeMint(msg.sender, newTokenID);
        _tokenIds.increment(); 
    }

    ///@dev Function returns all tokens owned by an account
    function tokensOfOwner(address _owner) external view returns (uint[] memory) {
        // where does this balance of function come from? open zep?
        uint tokenCount = balanceOf(_owner);
        uint[] memory tokensId = new uint256[](tokenCount);

        for(uint i = 0; i < tokenCount; i++) {
            // iterates through view function of token by owner and adds to uint[]
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
    
        return tokensId;
    }

    ///@dev Privileged function to withdraw money in contract
    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "Nothing in this piggy bank cap'n");

        
        // how does this work?? when does the money get sent? 
        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed!~"); 
    }
 
}
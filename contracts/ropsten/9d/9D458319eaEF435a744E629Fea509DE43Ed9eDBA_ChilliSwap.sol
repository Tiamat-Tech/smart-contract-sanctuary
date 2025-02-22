// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./IChilliSwap.sol";

contract ChilliSwap is ERC721, IChilliSwap,Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    mapping(string => uint8) hashes;
    mapping(uint256 => Artwork) private artworks;
    mapping(address => uint8) private creators;

    address public nftMarketContract;


    constructor() ERC721("ChilliSwapNFT", "CHLINFT") {}


    function mintNFT(address recipient, string memory metadata, string memory artwork,  uint256 royalty ) public override returns (uint256) {
        require(hashes[metadata] != 1);
        require(hashes[artwork] != 1);
        require(creators[msg.sender] == 1, "ChilliSwap: be a creator");
        require(royalty <= 50);

        hashes[metadata] = 1;
        hashes[artwork] = 1;
      
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        artworks[newItemId] = Artwork(block.timestamp, msg.sender, artwork, metadata, royalty);
        _mint(recipient, newItemId);
       // _setTokenURI(newItemId, tokenURI);
        emit Mint(recipient, newItemId, artwork);
        return newItemId;

    }



  function mintAndApproveNFT(address recipient, string memory metadata, string memory artwork,  uint256 royalty ) public override returns (uint256) {
        
        require(hashes[metadata] != 1);
        require(hashes[artwork] != 1);
        require(creators[msg.sender] == 1, "ChilliSwap: be a creator");
        require(royalty <= 50);

        hashes[metadata] = 1;
        hashes[artwork] = 1;
      
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        artworks[newItemId] = Artwork(block.timestamp, msg.sender, artwork, metadata, royalty);
        _mint(recipient, newItemId);

        emit Mint(recipient, newItemId, artwork);
        _approve(nftMarketContract, newItemId);

        return newItemId;

    }



    function burnNFT(uint256 tokenId) public override returns(bool){
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        Artwork memory artwork = artworks[tokenId];

        delete artworks[tokenId];
        delete hashes[artwork.metadata];
        delete hashes[artwork.artwork];

       _burn(tokenId);

       return true;

    }

    function getArtwork(uint256 tokenId) public view override returns (Artwork memory){
        require( _exists(tokenId), "ERC721: approved query for nonexistent token" );
        return artworks[tokenId];
    }

    function isCreator(address creator) public view override returns(bool){
        return creators[creator] == 1;
    }


    function addCreator(address creator) public override onlyOwner returns(bool){
        require(creators[creator] != 1, "ChilliSwap: creator already exist");
        creators[creator] = 1;
        return true;
    }
    function removeCreator(address creator)  public  override onlyOwner returns(bool){
        require(creators[creator] == 1, "ChilliSwap: creator doesn't exist");
        creators[creator] = 0;
        return true;
    }
    
    function setNftMarketContract(address marketContract) public  override onlyOwner returns(bool){
       nftMarketContract = marketContract;
        return true;
    }

    

  }
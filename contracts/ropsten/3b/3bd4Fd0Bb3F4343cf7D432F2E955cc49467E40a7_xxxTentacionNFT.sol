// SPDX-License-Identifier: MIT

/**
 * @title xxxTentacionNFT
 * @author Saad Sarwar
 */


pragma solidity ^0.8.4;

import "./token/ERC721/ERC721.sol";
import "./math/SafeMath.sol";
import "./access/Ownable.sol";
import "./utils/Counters.sol";


contract xxxTentacionNFT is ERC721, Ownable {
    //    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public nftPrice; //0.4 ether

    uint256 public MAX_SUPPLY; // max supply of nfts

    bool public saleIsActive = false; // to control sale

    address payable public treasury;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    // Token URI
    string public baseURI;

    event NftMinted(address to, uint date, uint tokenId, string tokenURI); // Used to generate NFT data on external decentralized storage service

    constructor(uint256 maxNftSupply, address payable _treasury) ERC721("xxxTentacion", "XTC") {
        MAX_SUPPLY = maxNftSupply;
        treasury = _treasury;
    }

    function setSalePrice(uint price) public onlyOwner {
        nftPrice = price;
    }

    function changeTreasuryAddress(address payable _newTreasuryAddress) public onlyOwner {
        require(_newTreasuryAddress != address(0), "cannot be a zero address");
        treasury = _newTreasuryAddress;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        require(bytes(baseURI).length == 0, 'BaseURI is already set.');
        baseURI = _newBaseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    /*
    * Pause sale if active, make active if paused
    */
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    // the default mint function for public sale
    function mint() public payable {
        require(nftPrice != 0, "NFT price not set yet");
        require(bytes(baseURI).length > 0, 'Base URI is not set.');
        require(saleIsActive, "Sale must be active to mint nft");
        require((totalSupply() + 1) <= MAX_SUPPLY, "Purchase would exceed max supply of NFTs");
        require(msg.value >= nftPrice, "Not enough balance");
        treasury.transfer(msg.value);
        _tokenIds.increment();
        uint256 newNftId = _tokenIds.current();
        _safeMint(msg.sender, newNftId);
        emit NftMinted(msg.sender, block.timestamp, newNftId, tokenURI(newNftId));
    }

    // mint for function to mint an nft for a given address, can be called only by owner
    function mintFor(address _to) public payable onlyOwner() {
        require(bytes(baseURI).length > 0, 'Base URI is not set.');
        require(saleIsActive, "Sale must be active to mint nft");
        require((totalSupply() + 1) <= MAX_SUPPLY, "Purchase would exceed max supply of NFTs");
        _tokenIds.increment();
        uint256 newNftId = _tokenIds.current();
        _safeMint(_to, newNftId);
        emit NftMinted(msg.sender, block.timestamp, newNftId, tokenURI(newNftId));
    }

    // mass minting function
    function massMint(address[] memory addresses) public payable onlyOwner() {
        uint index;
        for (index = 0; index < addresses.length; index++) {
            mintFor(addresses[index]);
        }
    }

}
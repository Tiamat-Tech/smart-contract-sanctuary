// SPDX-License-Identifier: MIT

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

    uint256 public constant nftPrice = 400000000000000000; //0.4 ether

    uint256 public MAX_SUPPLY; // max supply of nfts

    bool public saleIsActive = false; // to control sale

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Token URI
    string public baseURI;

    event NftMinted(address to, uint date, uint tokenId, string tokenURI); // Used to generate NFT data on external decentralized storage service

    constructor(uint256 maxNftSupply) ERC721("MAINSTREET", "MAINST") {
        MAX_SUPPLY = maxNftSupply;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        require(bytes(baseURI).length == 0, 'BaseURI is already set.');
        baseURI = _newBaseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function totalSupply() public view returns(uint256) {
        return _tokenIds.current();
    }

    /*
    * Pause sale if active, make active if paused
    */
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function mintNFT() public payable {
        require(bytes(baseURI).length > 0, 'Base URI is not set.');
        require(saleIsActive, "Sale must be active to mint nft");
        require((totalSupply() + 1) <= MAX_SUPPLY, "Purchase would exceed max supply of NFTs");
        require(msg.value >= nftPrice, "Not enough balance");
        _tokenIds.increment();
        uint256 newNftId = _tokenIds.current();
        _safeMint(msg.sender, newNftId);
        emit NftMinted(msg.sender, block.timestamp, newNftId, tokenURI(newNftId));
    }

}
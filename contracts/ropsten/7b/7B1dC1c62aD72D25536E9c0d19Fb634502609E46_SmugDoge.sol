// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SmugDoge is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 private _maxSupply = 690;
    string public _baseURL;
    uint256 public launchDate;
    mapping (uint256 => string) tokenUrls;

    constructor() ERC721("SmugDoge", "SMD") {
        setBaseURL("ipfs://");
    }

    function mint(string memory metadataURI) external payable {
        require(_tokenIds.current() < _maxSupply, "Can not mint more than max supply");
        require(msg.value >= 0.01 ether, "Insufficient payment");

        _safeMint(msg.sender, _tokenIds.current());
        setTokenURL(_tokenIds.current(), metadataURI);
        _tokenIds.increment();
    }

    

    function setTokenURL(uint256 tokenId, string memory ipfsUrl) private {
        tokenUrls[tokenId] = ipfsUrl;
    }

    function getTokenURL(uint256 tokenId) public view returns(string memory) {
        return tokenUrls[tokenId];
    }

    function setBaseURL(string memory baseURI) public onlyOwner {
        _baseURL = baseURI;
    }


    function setMaxSupply(uint256 value) public onlyOwner {
        _maxSupply = value;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURL;
    }
 

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }


    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }
}
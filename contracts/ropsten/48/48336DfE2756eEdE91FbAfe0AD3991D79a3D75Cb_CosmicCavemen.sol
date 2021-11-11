// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CosmicCavemen is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    string public baseTokenURI;
    string public cavemenProvenance = "";

    uint256 public constant MAX_CAVEMEN = 10001;
    uint256 public constant MAX_PRESALE = 2000;
    uint256 public constant PRICE = 0.08 ether;
    uint256 public constant MAX_CAVEMEN_PER_MINT = 10;
    uint256 public constant MAX_CAVEMEN_PER_PRESALE = 2;
    uint256 public constant RESERVED_CAVEMEN = 50;

    bool public isSaleActive = false;

    constructor(string memory baseURI) ERC721("CosmicCavemen", "CVMN") {
        setBaseURI(baseURI);
    }

    function totalTokens() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function _baseURI() internal view virtual override returns (string memory) {  // TODO: THIS FUNCTION IS NOT WORKING
        return baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        cavemenProvenance = provenanceHash;
    }

    function flipSaleState() public onlyOwner {
        isSaleActive = !isSaleActive;
    }

    function reserveCavemen() public onlyOwner {
        uint256 totalMinted = totalTokens();
        require(totalMinted.add(RESERVED_CAVEMEN) <= MAX_CAVEMEN, "Not enough Cavemen left to mint that amount.");

        for(uint256 i = 0; i < RESERVED_CAVEMEN; i++) {
            _mintOneCaveman();
        }
    }

    function mintCavemen(uint256 numTokens) public payable {
        uint256 totalMinted = totalTokens();
        require(isSaleActive, "Sale is not active.");
        require(numTokens <= MAX_CAVEMEN_PER_MINT && numTokens > 0, "You cannot mint that amount");
        require(totalMinted.add(numTokens) <= MAX_CAVEMEN, "Not enough Cavemen left to mint that amount.");
        require(PRICE.mul(numTokens) <= msg.value, "Not enough ether to purchase that amount");

        for(uint256 i = 0; i < numTokens; i++) {
            _mintOneCaveman();
        }
    }

    function _mintOneCaveman() private {
        _tokenIdCounter.increment();
        uint256 newTokenId = totalTokens();
        _safeMint(msg.sender, newTokenId);
    }

    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");
        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    // TODO: RANDOMIZE STARTING INDEX AFTER ALL TOKENS HAVE BEEN MINTED
}
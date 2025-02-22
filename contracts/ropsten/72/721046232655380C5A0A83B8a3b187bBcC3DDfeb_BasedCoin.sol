// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract BasedCoin is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    uint256 public constant MAX_BASED = 10000;
    uint256 public constant MAX_PURCHASE = 10;

    uint256 public PRICE_PER_BASED = 50000000000000000 wei;

    bool private _saleIsActive = false;

    string private _metaBaseUri = "";

    string private _provenance = "";

    constructor() ERC721("BASEDCOIN", "BC") { }

    function mint(uint16 numberOfTokens) public payable {
        require(saleIsActive(), "Sale is not active");
        require(numberOfTokens <= MAX_PURCHASE, "Can only mint 10 tokens per transaction");
        require(totalSupply().add(numberOfTokens) <= MAX_BASED, "Insufficient supply");
        require(PRICE_PER_BASED.mul(numberOfTokens) == msg.value, "Ether value sent is incorrect");

        _mintTokens(numberOfTokens);
    }


    /* Owner functions */

    /**
     * Reserve a few BASEDDDD for Marketing/Community Engagement
     */
    function reserve(uint16 numberOfTokens) external onlyOwner {
        require(totalSupply().add(numberOfTokens) <= MAX_BASED, "Insufficient supply");
        _mintTokens(numberOfTokens);
    }

    function setSaleIsActive(bool active) external onlyOwner {
        _saleIsActive = active;
    }

    function setTokenPrice(uint256 price) external onlyOwner {
        PRICE_PER_BASED = price;
    }

    function setProvenance(string memory provHash) external onlyOwner {
        _provenance = provHash;
    }

    function setMetaBaseURI(string memory baseURI) external onlyOwner {
        _metaBaseUri = baseURI;
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, 'Insufficient balance');
        payable(msg.sender).transfer(amount);
    }

    function withdrawAll() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /* View functions */
    function saleIsActive() public view returns (bool) {
        return _saleIsActive;
    }

    function provenanceHash() public view returns (string memory) {
        return _provenance;
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        return string(abi.encodePacked(_baseURI(), uint256(tokenId).toString(), ".json"));
    }

    /* Internal functions */
    function _mintTokens(uint16 numberOfTokens) internal {
        for (uint16 i = 0; i < numberOfTokens; i++) {
            uint256 tokenId = totalSupply();
            _safeMint(msg.sender, tokenId);
        }
    }

    function _baseURI() override internal view returns (string memory) {
        return _metaBaseUri;
    }
}
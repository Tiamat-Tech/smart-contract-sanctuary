// contracts/NFTSale.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract NFTSale is ERC721, Ownable {

    using SafeMath for uint256;

    string public NFT_PROVENANCE = "";

    uint256 public constant MAX_TOKENS_PER_PURCHASE = 20;

    uint256 private price = 25000000000000000; // 0.025 Ether

    bool public isSaleActive = true;

    uint256 public maxTotalSupply;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxTotalSupply
    ) ERC721(_name, _symbol) {
        maxTotalSupply = _maxTotalSupply;
    }

    function mint(uint256 _count) public payable {
        uint256 totalSupply = totalSupply();

        require(isSaleActive, "Sale is not active" );
        require(_count > 0 && _count < MAX_TOKENS_PER_PURCHASE + 1, "Exceeds maximum tokens you can purchase in a single transaction");
        require(totalSupply + _count < maxTotalSupply + 1, "Exceeds maximum tokens available for purchase");
        require(msg.value >= price.mul(_count), "Ether value sent is not correct");
        
        for(uint256 i = 0; i < _count; i++){
            _safeMint(msg.sender, totalSupply + i);
        }
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
    }

    function setProvenanceHash(string memory _provenanceHash) public onlyOwner {
        NFT_PROVENANCE = _provenanceHash;
    }

    function setSaleStatus(bool _isSaleActive) public onlyOwner {
        require(isSaleActive != _isSaleActive, "Status is the same");
        isSaleActive = _isSaleActive;
    }

    function setPrice(uint256 _newPrice) public onlyOwner() {
        price = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return price;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        msg.sender.transfer(balance);
    }
}
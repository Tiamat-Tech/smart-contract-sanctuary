// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC721Impl is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 private _price = 10000000000000000;  //0.01
    uint256 private _max = 200;
    string private baseURI;

    constructor(string memory tokenName_, string memory tokenSymbol_, string memory baseURI_) ERC721(tokenName_, tokenSymbol_) {
        baseURI = baseURI_;
    }

    function purchase() public payable returns (uint256) {
        return purchaseTo(msg.sender);
    }

    function purchaseTo(address recipient) public payable returns (uint256) {
        require(msg.value >= _price, "Must send enough to cover price");
        require(_tokenIds.current() <= _max, "Must not exceed max tokens");

        return _mintToken(recipient);
    }

    function mint() public onlyOwner returns (uint256) {
        return _mintToken(msg.sender);
    }

    function _mintToken(address recipient) internal returns (uint256) {
        _tokenIds.increment();
        _mint(recipient, _tokenIds.current());

        return _tokenIds.current();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
    
    function contractURI() public view returns (string memory) {
        return string(abi.encodePacked(_baseURI(), "metadata"));
    }
    
    function price() public view returns (uint256) {
        return _price;
    }

    function updatePrice(uint256 price_) public onlyOwner returns (uint256) {
        _price = price_;
        return _price;
    }
    
    function max() public view returns (uint256) {
        return _max;
    }

    function updateMax(uint256 max_) public onlyOwner returns (uint256) {
        _max = max_;
        return _max;
    }

}
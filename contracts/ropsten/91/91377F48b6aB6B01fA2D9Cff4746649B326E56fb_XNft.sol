// contracts/XNft.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract XNft is ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    uint256 public lastTokenId;
    uint256 public endId;
    mapping(uint256 => bool) public tokenSold;
    mapping(uint256 => string) public names;
    string public soldTokens;
    uint256 public soldTokensLength;
    uint256 public tokenPrice;
    address payable treasurer;
    uint256 public totalSale;

    event TokenSold(address indexed to, uint256 indexed tokenId, uint256 price, string name);
    event NameUpdated(uint256 indexed tokenId, string name);

    constructor(string memory _name, string memory _symbol, uint256 _endId) ERC721(_name, _symbol) {
        endId = _endId;
        tokenPrice = 4e17; //0.4 ETH
        treasurer = payable(msg.sender);
    }

    function updateEndId(uint256 _endId) external onlyOwner {
        endId = _endId;
    }

    function awardForSale(string memory tokenURI) public onlyOwner returns (uint256){
        require(lastTokenId < endId, "XNft: No further token can be minted.");
        lastTokenId = lastTokenId.add(1);
        _mint(address(this), lastTokenId);
        _setTokenURI(lastTokenId, tokenURI);
        return lastTokenId;
    }

    function updatePrice(uint256 _new_price) external onlyOwner {
        tokenPrice = _new_price;
    }

    function updateTreasurer(address payable _new_treasurer) external onlyOwner {
        treasurer = _new_treasurer;
    }

    function buy(uint256 _tokenId, string memory name) external payable {
        require(msg.value == tokenPrice, 'XNft: Wrong value to buy Token.');
        require(_tokenId <= lastTokenId, 'XNft: token not minted yet.');
        require(!tokenSold[_tokenId], 'XNft: Token already sold.');
        treasurer.transfer(msg.value);
        totalSale = totalSale.add(msg.value);
        tokenSold[_tokenId] = true;
        soldTokens = string(abi.encodePacked(soldTokens, _tokenId.toString(), ','));
        soldTokensLength = soldTokensLength.add(1);
        names[_tokenId] = name;
        this.transferFrom(address(this), msg.sender, _tokenId);
        emit TokenSold(msg.sender, _tokenId, msg.value, name);
    }

    function updateName(uint256 _tokenId, string memory new_name) external {
        require(ownerOf(_tokenId) == msg.sender, 'XNft: Only owner of token can update name.');
        names[_tokenId] = new_name;
        emit NameUpdated(_tokenId, new_name);
    }


}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract SFMNFT is ERC721URIStorage, Ownable, PullPayment, ReentrancyGuard {
    using Address for address payable;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint => address) tokenOwners;
    mapping(uint => uint) tokenUpgradablePrice;
    
    constructor() ERC721("NFTChain", "N-CHAIN") {}

    modifier onlyTokenOwner(uint256 _tokenId) {
        require(tokenOwners[_tokenId] == msg.sender, "not owner of the token");
        _;
    }

    function mintNFT(string memory _tokenURI, uint256 _uPrice) external returns (uint256)
    {
        _tokenIds.increment();

        uint256 tokenId = _tokenIds.current();
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        tokenOwners[tokenId] = msg.sender;
        tokenUpgradablePrice[tokenId] = _uPrice;
        return tokenId;
    }

    function updateTokenURI(uint256 _tokenId, string memory _tokenURI) public payable onlyTokenOwner(_tokenId) {
        require(msg.value >= tokenUpgradablePrice[_tokenId], "not enough amount");
         _setTokenURI(_tokenId, _tokenURI);
    }

    function withdraw() external payable onlyOwner{
        payable(msg.sender).sendValue(address(this).balance);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract GameNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter tokenIds;
    address marketAddress;

    event TokenMinted(uint256 indexed tokenId, address indexed to);

    constructor(address _marketAddress) ERC721("GNFT", "GNFT") {
        marketAddress = _marketAddress;
    }

    mapping(uint256 => address) _creators;

    function mintToken(string memory _tokenURI) external {
        tokenIds.increment();
        uint256 _newItemId = tokenIds.current();

        _mint(msg.sender, _newItemId);
        _creators[_newItemId] = msg.sender;
        _setTokenURI(_newItemId, _tokenURI);
        approve(marketAddress, _newItemId);

        emit TokenMinted(_newItemId, msg.sender);
    }

    function setMarketAddress(address _marketAddress) external onlyOwner {
        marketAddress = _marketAddress;
    }

    function getMarketAddress() external view returns (address) {
        return marketAddress;
    }

    function creatorOf(uint256 _tokenId) external view returns (address) {
        address creator = _creators[_tokenId];
        require(creator != address(0), "creator query for nonexistent token");
        return creator;
    }
}
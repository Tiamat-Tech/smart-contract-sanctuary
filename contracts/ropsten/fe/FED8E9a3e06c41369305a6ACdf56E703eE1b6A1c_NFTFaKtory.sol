// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

//import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MockToken.sol";

contract NFTFaKtory is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address public mockTokenAddress;

    event MintedNFT(uint256 indexed itemId);

    constructor(address _mockTokenAddress) ERC721("NFT FaKtory", "FAK") {
        mockTokenAddress = _mockTokenAddress;
    }

    // function mint(string memory tokenURI)
    //     public
    //     returns (uint256)
    // {
    //     _tokenIds.increment();

    //     uint256 newItemId = _tokenIds.current();
    //     _mint(msg.sender, newItemId);
    //     _setTokenURI(newItemId, tokenURI);
    //     emit MintedNFT(newItemId);
    //     return newItemId;
    // }

    function mintAndPay(string memory tokenURI, uint256 amount)
        external
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        MockToken(mockTokenAddress).burnFrom(msg.sender, amount);
        _setTokenURI(newItemId, tokenURI);
        emit MintedNFT(newItemId);
        return newItemId;
    }
}
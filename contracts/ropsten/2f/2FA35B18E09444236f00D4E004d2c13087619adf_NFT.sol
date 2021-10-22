// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract NFT is ERC721URIStorage {
    mapping (uint256 => bool) public tokenIdStatus;

    address public manager;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint public randomTokenPrice = 0.1 ether;
    uint public nonRandomTokenPrice = 0.2 ether;

    modifier restricted() {
        require(msg.sender == manager, "This Method is restricted");
        _;
    }

    constructor() ERC721("TokenMind", "TMFT") {
        manager = msg.sender;
    }

    function createToken(string memory tokenURI) public returns (uint) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        tokenIdStatus[newItemId] = true;
        return newItemId;
    }

    function buyRandomToken() external payable {
        uint tokenId = random();
        require(tokenIdStatus[tokenId] == true, 'This token is not for sale');
        require(msg.value == randomTokenPrice, 'Incorrect value');

        address seller = ownerOf(tokenId);
        _transfer(seller, msg.sender, tokenId);
        tokenIdStatus[tokenId] = false; // not for sale anymore
        payable(seller).transfer(msg.value); // send the ETH to the seller
    }

    function buyToken(uint tokenId) external payable {
        require(tokenIdStatus[tokenId] == true, 'This token is not for sale');
        require(msg.value == nonRandomTokenPrice, 'Incorrect value');

        address seller = ownerOf(tokenId);
        _transfer(seller, msg.sender, tokenId);
        tokenIdStatus[tokenId] = false; // not for sale anymore
        payable(seller).transfer(msg.value); // send the ETH to the seller
    }

    function setRandomTokenPrice(uint newPrice) external restricted {
        randomTokenPrice = newPrice;
    }

    function setNonRandomTokenPrice(uint newPrice) external restricted {
        nonRandomTokenPrice = newPrice;
    }

    function getRandomTokenPrice() public view returns (uint) {
        return randomTokenPrice;
    }

    function getNonRandomTokenPrice() public view returns (uint) {
        return nonRandomTokenPrice;
    }

    function random() private view returns (uint) {
        uint lastTokenId = _tokenIds.current();
        uint randomId;
        uint loopCount;
        require(lastTokenId > 0, "There is no tokens yet");
        do {
            uint temp = (uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, loopCount))) % lastTokenId) + 1;
            loopCount ++;
            if (tokenIdStatus[temp] == true) {
                randomId = temp;
                break;
            } else {
                if (loopCount > lastTokenId) {
                    break;
                }
            }
        } while (randomId == 0);
        return randomId;
    }
}
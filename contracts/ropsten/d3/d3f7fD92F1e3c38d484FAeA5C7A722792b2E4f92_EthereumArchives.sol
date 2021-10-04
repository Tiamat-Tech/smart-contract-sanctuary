// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract EthereumArchives is ERC721Enumerable, ReentrancyGuard, Ownable {
    uint256 lastTokenId = 199;
    uint256 OWNER_RESERVATION_COUNT = 10;

    mapping(uint256 => string) private tokenIdToName;
    mapping(uint256 => uint256) private tokenIdToBlockNumber;
    mapping(uint256 => uint256) private blockNumberToTokenId;

    constructor() ERC721("Ethereum Archives", "ARCH") {}

    function mint(uint256 blockNumber, string memory name) public nonReentrant {
        uint256 tokenId = totalSupply() + 1;

        require(tokenId <= lastTokenId - OWNER_RESERVATION_COUNT, "Max supply reached");

        _mint(tokenId, blockNumber, name);
        _safeMint(_msgSender(), tokenId);
    }

    function ownerMint(uint256 tokenId, uint256 blockNumber, string memory name) public nonReentrant onlyOwner {
        require(tokenId > lastTokenId - OWNER_RESERVATION_COUNT && tokenId < lastTokenId, "Token id is invalid");

        _mint(tokenId, blockNumber, name);
        _safeMint(owner(), tokenId);
    }

    function burnAndMint(uint256 oldBlockNumber, uint256 newBlockNumber, string memory name) public nonReentrant {
        uint256 oldTokenId = blockNumberToTokenId[oldBlockNumber];

        require(oldTokenId > 0, "Block to burn is not minted");

        _transfer(
            msg.sender,
            0x000000000000000000000000000000000000dEaD,
            oldTokenId
        );

        uint256 newTokenId = totalSupply() + 1;
        _mint(newTokenId, newBlockNumber, name);
    }


    function setName(uint256 blockNumber, string memory name) public nonReentrant {
        uint256 tokenId = blockNumberToTokenId[blockNumber];

        _validateTokenId(tokenId);
        require(ownerOf(tokenId) == _msgSender(), "You are not the owner of the token.");

        tokenIdToName[tokenId] = name;
    }

    function getBlockNumber(uint256 tokenId) public view returns (uint256) {
        _validateTokenId(tokenId);

        return tokenIdToBlockNumber[tokenId];
    }

    function getName(uint256 blockNumber) public view returns (string memory) {
        uint256 tokenId = blockNumberToTokenId[blockNumber];
        _validateTokenId(tokenId);

        return tokenIdToName[tokenId];
    }

    function ownerOfBlock(uint256 blockNumber) public view returns (address) {
        uint256 tokenId = blockNumberToTokenId[blockNumber];
        _validateTokenId(tokenId);

        return ownerOf(tokenId);
    }

    function _mint(uint256 tokenId, uint256 blockNumber, string memory name) private {
        require(bytes(name).length > 0, "Name cannot be empty.");
        require(blockNumberToTokenId[blockNumber] == 0, "Block has already been minted.");

        tokenIdToName[tokenId] = name;
        tokenIdToBlockNumber[tokenId] = blockNumber;
        blockNumberToTokenId[blockNumber] = tokenId;
    }

    function _validateTokenId(uint256 tokenId) view private {
        require(tokenId > 0 && tokenId < lastTokenId, "Token ID invalid");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "libs/Base64.sol";

contract EthereumArchives is ERC721Enumerable, ReentrancyGuard, Ownable {
    uint256 lastTokenId = 199;
    uint256 OWNER_RESERVATION_COUNT = 10;
    uint256 MINTING_FEE = 0.07 ether;

    mapping(uint256 => uint256) private tokenIdToBlockNumber;
    mapping(uint256 => uint256) private blockNumberToTokenId;

    constructor() ERC721("Ethereum Archives", "ARCH") {}

    function ownerMint(uint256 tokenId, uint256 blockNumber) public nonReentrant onlyOwner {
         _validateBlockNumber(blockNumber);
        require(tokenId > lastTokenId - OWNER_RESERVATION_COUNT && tokenId < lastTokenId, "Token id is invalid");

        _mint(tokenId, blockNumber);
        _safeMint(owner(), tokenId);
    }

    function mint(uint256[] memory blockNumbers) public payable nonReentrant {
        require(blockNumbers.length < 11, "Cannot be minted more than 10 blocks at once");

        uint256 tokensLeft = lastTokenId - this.totalSupply() - OWNER_RESERVATION_COUNT;

        require(tokensLeft > 0, "Max supply reached");
        require(tokensLeft >= blockNumbers.length, string(abi.encodePacked("Only ", Strings.toString(tokensLeft), " tokens left")));
        require(msg.value >= MINTING_FEE * blockNumbers.length, "Not enough ether sent!");

        uint256 startTokenId = totalSupply() + 1;

        for (uint256 i = 0; i < blockNumbers.length; i++) {
            uint256 tokenId = startTokenId + i;
            uint256 blockNumber = blockNumbers[i];

            _validateBlockNumber(blockNumber);

            _mint(tokenId, blockNumber);
            _safeMint(_msgSender(), tokenId);
        }
    }

    function burnAndMint(uint256 oldBlockNumber, uint256 newBlockNumber) public nonReentrant {
        _validateBlockNumber(oldBlockNumber);
        _validateBlockNumber(newBlockNumber);
        uint256 oldTokenId = blockNumberToTokenId[oldBlockNumber];

        require(oldTokenId > 0, "Block to burn is not minted");

        _transfer(
            msg.sender,
            0x000000000000000000000000000000000000dEaD,
            oldTokenId
        );

        uint256 newTokenId = totalSupply() + 1;
        _mint(newTokenId, newBlockNumber);
    }

    function getBlockNumber(uint256 tokenId) public view returns (uint256) {
        _validateTokenId(tokenId);

        return tokenIdToBlockNumber[tokenId];
    }

    function ownerOfBlock(uint256 blockNumber) public view returns (address) {
        _validateBlockNumber(blockNumber);
        uint256 tokenId = blockNumberToTokenId[blockNumber];
        _validateTokenId(tokenId);

        return ownerOf(tokenId);
    }

    function tokenURI(uint256 blockNumber) override public view returns (string memory) {
        _validateBlockNumber(blockNumber);
        string[18] memory parts;

        parts = [
            '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
                '<style>.base { fill: black; font-family: "VT323", monospace; }; .text-default { font-size: 16px; }; .text-small { font-size: 12px };</style>',
                '<rect width="100%" height="100%" fill="white" />',
                '<text y="60" x="50%" text-anchor="middle" class="base text-default">',
                    'Block #',
                    Strings.toString(blockNumber),
                '</text>',
                '<svg x="143" y="123" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" width="64px" viewBox="0 0 92 149">',
                    '<g>',
                        '<path style=" stroke:none;fill-rule:nonzero;fill:rgb(20.392157%,20.392157%,20.392157%);fill-opacity:1;" d="M 45.988281 0.0117188 L 44.980469 3.40625 L 44.980469 101.910156 L 45.988281 102.910156 L 91.972656 75.882812 Z M 45.988281 0.0117188 "/>',
                        '<path style=" stroke:none;fill-rule:nonzero;fill:rgb(54.901961%,54.901961%,54.901961%);fill-opacity:1;" d="M 45.988281 0.0117188 L 0 75.882812 L 45.988281 102.910156 Z M 45.988281 0.0117188 "/>',
                        '<path style=" stroke:none;fill-rule:nonzero;fill:rgb(23.529412%,23.529412%,23.137255%);fill-opacity:1;" d="M 45.988281 111.566406 L 45.421875 112.253906 L 45.421875 147.34375 L 45.988281 148.988281 L 92 84.550781 Z M 45.988281 111.566406 "/>',
                        '<path style=" stroke:none;fill-rule:nonzero;fill:rgb(54.901961%,54.901961%,54.901961%);fill-opacity:1;" d="M 45.988281 148.988281 L 45.988281 111.566406 L 0 84.550781 Z M 45.988281 148.988281 "/>',
                        '<path style=" stroke:none;fill-rule:nonzero;fill:rgb(7.843137%,7.843137%,7.843137%);fill-opacity:1;" d="M 45.988281 102.910156 L 91.972656 75.882812 L 45.988281 55.097656 Z M 45.988281 102.910156 "/>',
                        '<path style=" stroke:none;fill-rule:nonzero;fill:rgb(22.352941%,22.352941%,22.352941%);fill-opacity:1;" d="M 0 75.882812 L 45.988281 102.910156 L 45.988281 55.097656 Z M 0 75.882812 "/>',
                    '</g>',
                '</svg>',
            '</svg>'
        ];

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));
        output = string(abi.encodePacked(output, parts[9], parts[10], parts[11], parts[12], parts[13], parts[14], parts[15], parts[16], parts[17]));

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Block #', Strings.toString(blockNumber),
                        '", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)),
                        '", "description": "The Ethereum Archive is a fully on-chain community owned, curated and evolving archive of historic blocks the Ethereum blockchain. Each Archive token represents a unique ethereum block. The owner has the right to burn and mint a new token representing any block that has not been claimed."}'
                    )
                )
            )
        );
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }

    function _mint(uint256 tokenId, uint256 blockNumber) private {
        require(blockNumberToTokenId[blockNumber] == 0, "Block has already been minted.");

        tokenIdToBlockNumber[tokenId] = blockNumber;
        blockNumberToTokenId[blockNumber] = tokenId;
    }

    function _validateTokenId(uint256 tokenId) view private {
        require(tokenId > 0 && tokenId < lastTokenId, "Token ID invalid");
    }

    function _validateBlockNumber(uint256 blockNumber) view private {
        require(blockNumber >= 0 && blockNumber < block.number, "Block number is invalid");
    }
}
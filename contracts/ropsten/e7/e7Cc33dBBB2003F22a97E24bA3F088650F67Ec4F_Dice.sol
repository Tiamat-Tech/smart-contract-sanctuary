//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Dice is ERC721Enumerable, ReentrancyGuard, Ownable {
    uint[] private currentRoll;
    uint nonce;

    string[] private materials = [
        "Amethyst",
        "Azurite",
        "Bone",
        "Cat's Eye",
        "Copper",
        "Diamond",
        "Emerald",
        "Garnet",
        "Gold",
        "Iron",
        "Jade",
        "Jasper",
        "Lead",
        "Nickel",
        "Obsidian",
        "Onyx",
        "Opal",
        "Pearl",
        "Platinum",
        "Quartz",
        "Ruby",
        "Sapphire",
        "Silver",
        "Tiger Eye",
        "Titanium",
        "Topaz",
        "Tungsten",
        "Turquoise"
    ];

    string[] private adjectives = [
        "Enchanted",
        "Cursed",
        "Glowing",
        "Bewitched",
        "Raw",
        "Carved",
        "Polished",
        "Mysterious",
        "Shimmering",
        "Shiny",
        "Demonic",
        "Blessed",
        "Holy",
        "Brilliant",
        "Enlightened",
        "Divine"
    ];

    function roll() public onlyOwner {
        uint first = randomNumber();
        uint second = randomNumber();
        currentRoll = [first, second];
    }

    function getCurrentRoll() public view returns (uint[] memory) {
       return currentRoll;
    }

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function randomNumber() internal returns (uint) {
        uint randomnumber = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 20;
        nonce++;
        return randomnumber;
    }

    function getMaterial(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "MATERIAL", materials);
    }

    function getAdjective(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "ADJECTIVE", adjectives);
    }

    function getText(uint256 tokenId) public view returns (string memory) {
       return string(abi.encodePacked(getAdjective(tokenId), ' ', getMaterial(tokenId)));
    }

    function pluck(uint256 tokenId, string memory keyPrefix, string[] memory sourceArray) internal pure returns (string memory) {
        uint256 rand = random(string(abi.encodePacked(keyPrefix, Strings.toString(tokenId))));
        string memory output = sourceArray[rand % sourceArray.length];
        return output;
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        string[17] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';
        parts[1] = getText(tokenId);
        parts[2] = '</text></svg>';

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2]));
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Dice #', Strings.toString(tokenId), '", "description": "", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }

    function claim(uint256 tokenId) public nonReentrant {
        require(tokenId > 8000 && tokenId < (block.number / 10) + 1, "Token ID invalid");
        _safeMint(_msgSender(), tokenId);
    }
    
    constructor() ERC721("Dice", "NFT") Ownable() {}
}

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}
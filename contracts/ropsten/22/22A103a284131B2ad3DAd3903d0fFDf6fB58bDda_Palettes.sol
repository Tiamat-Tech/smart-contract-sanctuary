//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "base64-sol/base64.sol";

library RGBAx8 {
    bytes16 private constant _HEX_SYMBOLS = "0123456789ABCDEF";

    uint32 private constant maskR = 0xff000000;
    uint32 private constant maskG = 0x00ff0000;
    uint32 private constant maskB = 0x0000ff00;
    uint32 private constant maskA = 0x000000ff;

    function hexRGBA(uint256 id, uint256 i) public pure returns (string memory) {
        require(i < 8, "Color index out of bounds");

        uint256[8] memory masks = [
            0xffffffff00000000000000000000000000000000000000000000000000000000,
            0x00000000ffffffff000000000000000000000000000000000000000000000000,
            0x0000000000000000ffffffff0000000000000000000000000000000000000000,
            0x000000000000000000000000ffffffff00000000000000000000000000000000,
            0x00000000000000000000000000000000ffffffff000000000000000000000000,
            0x0000000000000000000000000000000000000000ffffffff0000000000000000,
            0x000000000000000000000000000000000000000000000000ffffffff00000000,
            0x00000000000000000000000000000000000000000000000000000000ffffffff
        ];

        uint32 color = uint32((id & masks[i]) >> ((7 - i) * 32));

        /**
         * Converts color `uint32` to its ASCII `string` hexadecimal
         * representation without a 0x prefix for use in RGBA colors.
         * based on the OpenZeppelin Strings library
         * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.4.0/contracts/utils/Strings.sol
         */
        bytes memory buffer = new bytes(8);
        for (uint256 j = 0; j < 8; j++) {
            buffer[7-j] = _HEX_SYMBOLS[color & 0xf];
            color >>= 4;
        }

        string memory hexString = string(buffer);

        return string(abi.encodePacked("#", hexString));
    }

    function colors(uint256 id) external pure returns (string memory) {
        return string(abi.encodePacked(
                                       "["
                                       "\"", hexRGBA(id, 0), "\","
                                       "\"", hexRGBA(id, 1), "\","
                                       "\"", hexRGBA(id, 2), "\","
                                       "\"", hexRGBA(id, 3), "\","
                                       "\"", hexRGBA(id, 4), "\","
                                       "\"", hexRGBA(id, 5), "\","
                                       "\"", hexRGBA(id, 6), "\","
                                       "\"", hexRGBA(id, 7), "\""
                                       "]"
                                       ));
    }
}

contract Palettes is ERC721Enumerable, ReentrancyGuard {
    using RGBAx8 for uint256;

    constructor () ERC721("Palettes", "RGBAx8") {}

    function claim(uint256 tokenId) public nonReentrant {
        _safeMint(_msgSender(), tokenId);
    }

    function join(
        string memory a,
        string memory b,
        string memory c
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c));
    }

    function getHexRGBA(uint256 id, uint8 i) external pure returns (string memory) {
        return id.hexRGBA(i);
    }

    function getColors(uint256 id) external pure returns (string memory) {
        return id.colors();
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {

        /* example svg output
          <svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">
            <rect x="0" y="0" width="26%" height="51%" style="fill:#000000FF" />
            <rect x="25%" y="0" width="26%" height="51%" style="fill:#0000FFFF" />
            <rect x="50%" y="0" width="26%" height="51%" style="fill:#00FF00FF" />
            <rect x="75%" y="0" width="25%" height="51%" style="fill:#FF0000FF" />
            <rect x="0" y="50%" width="26%" height="50%" style="fill:#FFFF00FF" />
            <rect x="25%" y="50%" width="26%" height="50%" style="fill:#00FFFFFF" />
            <rect x="50%" y="50%" width="26%" height="50%" style="fill:#aFFFF0FF" />
            <rect x="75%" y="50%" width="25%" height="50%" style="fill:#0FFFa0FF" />
          </svg>
        */

        string memory part0 = "<svg xmlns=\"http://www.w3.org/2000/svg\" preserveAspectRatio=\"xMinYMin meet\" viewBox=\"0 0 350 350\">";
        string memory part1 = join("<rect x=\"0\" y=\"0\" width=\"26%\" height=\"51%\" style=\"fill:",
                                   id.hexRGBA(0),
                                   "\" />"
                                   );
        string memory part2 = join("<rect x=\"25%\" y=\"0\" width=\"26%\" height=\"51%\" style=\"fill:",
                                   id.hexRGBA(1),
                                   "\" />"
                                   );
        string memory part3 = join("<rect x=\"50%\" y=\"0\" width=\"26%\" height=\"51%\" style=\"fill:",
                                   id.hexRGBA(2),
                                   "\" />"
                                   );
        string memory part4 = join("<rect x=\"75%\" y=\"0\" width=\"25%\" height=\"51%\" style=\"fill:",
                                   id.hexRGBA(3),
                                   "\" />"
                                   );
        string memory part5 = join("<rect x=\"0\" y=\"50%\" width=\"26%\" height=\"50%\" style=\"fill:",
                                   id.hexRGBA(4),
                                   "\" />"
                                   );
        string memory part6 = join("<rect x=\"25%\" y=\"50%\" width=\"26%\" height=\"50%\" style=\"fill:",
                                   id.hexRGBA(5),
                                   "\" />"
                                   );
        string memory part7 = join("<rect x=\"50%\" y=\"50%\" width=\"26%\" height=\"50%\" style=\"fill:",
                                   id.hexRGBA(6),
                                   "\" />"
                                   );
        string memory part8 = join("<rect x=\"75%\" y=\"50%\" width=\"25%\" height=\"50%\" style=\"fill:",
                                   id.hexRGBA(7),
                                   "\" /></svg>"
                                   );
        bytes memory svg = abi.encodePacked(part0,
                                            part1,
                                            part2,
                                            part3,
                                            part4,
                                            part5,
                                            part6,
                                            part7,
                                            part8
                                            );
        return string(abi.encodePacked("data:image/svg+xml;base64,",
                                       Base64.encode(svg)
                                       ));
    }
}
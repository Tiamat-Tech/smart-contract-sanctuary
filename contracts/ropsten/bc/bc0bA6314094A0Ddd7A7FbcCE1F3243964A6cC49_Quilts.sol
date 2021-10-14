//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./QuiltGenerator.sol";

contract Quilts is ERC721Enumerable, ReentrancyGuard, Ownable {
    uint256 public maxSupply = 4000;
    uint256 public price = 0.025 ether;
    uint256 public maxPerTx = 20;
    uint256 public tokensMinted;
    bool public isSaleActive = false;

    string[] private colorNames = [
        "Pink panther",
        "Cherry blossom",
        "Desert",
        "Forest",
        "Mushroom",
        "Ocean",
        "Twilight",
        "Pumpkin",
        "B&W"
    ];

    string[] private backgroundNames = ["Speckled", "Pointing", "Caustics"];

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        string memory tokenIdStr = Strings.toString(tokenId);
        QuiltGenerator.QuiltStruct memory quilt = QuiltGenerator
            .getQuiltForSeed(tokenIdStr);

        string memory svg = QuiltGenerator.getQuiltSVG(tokenIdStr, quilt);

        string memory traits = string(
            abi.encodePacked(
                '[{"trait_type":"Background","value":"',
                backgroundNames[quilt.backgroundIndex],
                '"},{"trait_type":"Theme","value":"',
                colorNames[quilt.themeIndex],
                '"},{"trait_type":"Patches","value":',
                Strings.toString(quilt.patchXCount * quilt.patchYCount),
                '},{"trait_type":"Aspect ratio","value":"',
                Strings.toString(quilt.patchXCount),
                ":",
                Strings.toString(quilt.patchYCount),
                '"},{"trait_type":"Hovers","value":"',
                quilt.hovers ? "true" : "false",
                '"}]'
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"Quilt #',
                        tokenIdStr,
                        '","description":"Quilts are randomly generated and stored on-chain. Get one for yourself and stay cosy.","attributes":',
                        traits,
                        ',"image":"data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '"}'
                    )
                )
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    function mint(address to, uint256 numTokens) private {
        if (to != owner()) {
            require(isSaleActive, "Sale not active");
        }
        require(totalSupply() < maxSupply, "All quilts minted");
        require(
            totalSupply() + numTokens <= maxSupply,
            "Minting exceeds max supply"
        );
        require(numTokens <= maxPerTx, "Mint fewer quilts");
        require(numTokens > 0, "Must mint at least 1 quilt");
        require(price * numTokens == msg.value, "ETH amount is incorrect");

        for (uint256 i = 0; i < numTokens; i++) {
            uint256 tokenId = tokensMinted + 1;
            _safeMint(to, tokenId);
            tokensMinted += 1;
        }
    }

    function claim(uint256 numTokens) public payable virtual {
        mint(_msgSender(), numTokens);
    }

    function toggleSale() public onlyOwner {
        isSaleActive = !isSaleActive;
    }

    function withdrawAll() public payable nonReentrant onlyOwner {
        require(payable(_msgSender()).send(address(this).balance));
    }

    constructor() ERC721("Quilts", "QUILTS") {}
}

library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";
        uint256 encodedLen = 4 * ((len + 2) / 3);
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
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
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
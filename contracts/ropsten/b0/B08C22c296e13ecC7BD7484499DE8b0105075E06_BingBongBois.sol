/*

██████╗ ██╗███╗  ██╗ ██████╗
██╔══██╗██║████╗ ██║██╔════╝
██████╦╝██║██╔██╗██║██║  ██╗
██╔══██╗██║██║╚████║██║  ╚██╗
██████╦╝██║██║ ╚███║╚██████╔╝
╚═════╝ ╚═╝╚═╝  ╚══╝ ╚═════╝

██████╗  █████╗ ███╗  ██╗ ██████╗
██╔══██╗██╔══██╗████╗ ██║██╔════╝
██████╦╝██║  ██║██╔██╗██║██║  ██╗
██╔══██╗██║  ██║██║╚████║██║  ╚██╗
██████╦╝╚█████╔╝██║ ╚███║╚██████╔╝
╚═════╝  ╚════╝ ╚═╝  ╚══╝ ╚═════╝

██████╗  █████╗ ██╗ ██████╗
██╔══██╗██╔══██╗██║██╔════╝
██████╦╝██║  ██║██║╚█████╗
██╔══██╗██║  ██║██║ ╚═══██╗
██████╦╝╚█████╔╝██║██████╔╝
╚═════╝  ╚════╝ ╚═╝╚═════╝

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

/// @title BingBongBois NFT collection
/// @author nat_nave
/// @notice Simulates a NFT collection, deployed on the Ropsten network.
contract BingBongBois is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Bing Bong Bois", "BBB") {
        // ensure tokenId starts at 1
        _tokenIdCounter.increment();
    }

    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant UNIT_PRICE = 0.042069 ether;
    /// @dev Hex symbol lookup for randomly generated colors.
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /// @dev Batch mint... will it work
    /// @param quantity number of tokens to mint
    function mint(uint256 quantity) external payable {
        require(msg.value >= quantity * UNIT_PRICE, "Incorrect value");
        require(quantity > 0);
        require(_tokenIdCounter.current() + quantity - 1 <= MAX_SUPPLY);

        // require(tx.origin == msg.sender, "Minting from contract disabled");

        for (uint256 count = 0; count < quantity; count++) {
            safeMint(msg.sender);
        }
    }

    /// @dev Safely mints a single token and transfers it to `_to`.
    /// @param _to address, cannot be zero
    function safeMint(address _to) private {
        uint256 tokenId = _tokenIdCounter.current();
        require((tokenId - 1) <= MAX_SUPPLY);
        _safeMint(_to, tokenId);
        _tokenIdCounter.increment();
    }

    /// @dev Generate hex color code 'randomly'
    /// @param tokenId 'unique' ID for color generation
    /// @return hexColorCode string where format is "#______"
    function generateRandomColor(uint256 tokenId)
        private
        pure
        returns (string memory)
    {
        uint256 notRandom = uint256(keccak256(abi.encodePacked(tokenId)));

        string memory hexColorCode = "#";
        /// @dev 6 hex characters, 24 bits, max value = 16777215 = 2^24 - 1
        uint256 divisor = 16777215;
        string memory hexChars = _toHexString(notRandom % divisor, 6);
        hexColorCode = string(abi.encodePacked(hexColorCode, hexChars));

        return hexColorCode;
    }

    /// @dev Draw SVG art for a specified tokenId
    /// @param tokenId tokenId to draw art for
    /// @return string representing the SVG art
    function drawSvg(uint256 tokenId) private pure returns (string memory) {
        string memory descriptor = string(
            abi.encodePacked(
                "<rect fill='",
                generateRandomColor(tokenId),
                "' x='0' y='0' height='32' width='32' />"
            )
        );

        return
            string(
                abi.encodePacked(
                    "<svg id='random-image' xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 32 32'>",
                    descriptor,
                    "<style>#random-image{shape-rendering:crispedges;}</style></svg>"
                )
            );
    }

    /// @dev View metadata for a specific token
    /// @param tokenId of token you wish to view metadata
    /// @return base64 encoded string
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId));

        return
            string(
                abi.encodePacked(
                    Base64.encode(
                        bytes(
                            string(
                                abi.encodePacked(
                                    "data:application/json;base64,",
                                    '{"name": Bing Bong Bois #',
                                    Strings.toString(tokenId),
                                    "description: Bing Bong Bois is a collection of ",
                                    Strings.toString(MAX_SUPPLY),
                                    " Bois, 'randomly' generated and fully on-chain.",
                                    '"image": "data:image/svg+xml;base64,',
                                    Base64.encode(bytes(drawSvg(tokenId))),
                                    '", "attributes": ,',
                                    "}"
                                )
                            )
                        )
                    )
                )
            );
    }

    /**
    @dev Modified from openzeppelin/contracts/utils/Strings.sol
    @dev Converts a `uint256` to its ASCII `string` hexadecimal
         representation with fixed length
    @param value uint256 value
    @param length number of characters to extract from right hand side
           which is the Least Significant Byte
    @return extracted string of specified length
     */

    function _toHexString(uint256 value, uint256 length)
        internal
        pure
        returns (string memory)
    {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");

        string memory extracted = "";
        for (uint256 i = buffer.length - length; i < buffer.length; ++i) {
            extracted = string(abi.encodePacked(extracted, buffer[i]));
        }
        return extracted;
    }

    /// @dev Withdraw specific amount to the owner's account
    /// @param _amount amount of ether to withdraw
    function withdrawAmount(uint256 _amount) public onlyOwner {
        require(_amount >= address(this).balance);
        payable(owner()).transfer(_amount);
    }

    /**
        @dev Hook that is called before any token transfer.
        openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol
    */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /// @dev openzeppelin/contracts/utils/introspection/IERC165.sol
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
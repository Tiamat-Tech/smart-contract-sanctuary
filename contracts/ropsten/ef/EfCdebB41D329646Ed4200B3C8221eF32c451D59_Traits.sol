// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.7;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IGNG.sol";

contract Traits is Ownable, ITraits { //rop 0x05122a08F1b918b0dF3c9Bf0Cc0220870b073702 rink 0xAFeC50365c31C85B39031405b5ab3Ab108dB6742

    using Strings for uint256;

    // struct to store each trait's data for metadata and rendering
    struct Trait {
        string name;
        string png;
    }

    // mapping from trait type (index) to its name
    string[9] private _traitTypes = [
    "Background",
    "Block",
    "Plot",
    "Name",
    "Fertility",
    "Frame",
    "Gangsters",
    "Houses",
    "Ground"
    ];
    // storage of each traits name and base64 PNG data
    mapping(uint8 => mapping(uint8 => Trait)) public traitData;
    // mapping from alphaIndex to its score
    string[4] _fertility = [
    "8",
    "7",
    "6",
    "5"
    ];

    IGNG public gng;

    function setGng(address _gng) external onlyOwner {
        gng = IGNG(_gng);
    }
    /**
     * administrative to upload the names and images associated with each trait
     * @param traitType the trait type to upload the traits for (see traitTypes for a mapping)
     * @param traits the names and base64 encoded PNGs for each trait
     */
    function uploadTraits(uint8 traitType, uint8[] calldata traitIds, Trait[] calldata traits) external onlyOwner {
        require(traitIds.length == traits.length, "Mismatched inputs");
        for (uint i = 0; i < traits.length; i++) {
            traitData[traitType][traitIds[i]] = Trait(
                traits[i].name,
                traits[i].png
            );
        }
    }

    /** RENDER */

    /**
     * generates an <image> element using base64 encoded PNGs
     * @param trait the trait storing the PNG data
     * @return the <image> element
     */
    function drawTrait(Trait memory trait) internal pure returns (string memory) {
        return string(abi.encodePacked(
                '<image x="4" y="4" width="32" height="32" image-rendering="pixelated" preserveAspectRatio="xMidYMid" xlink:href="data:image/png;base64,',
                trait.png,
                '"/>'
            ));
    }

    /**
     * generates an entire SVG by composing multiple <image> elements of PNGs
     * @param tokenId the ID of the token to generate an SVG for
     * @return a valid SVG of
     */
    function drawSVG(uint256 tokenId) public view returns (string memory) {
        IGNG.FarmBranch memory s = gng.getTokenTraits(tokenId);
//        uint8 shift = s.isFarm ? 0 : 9;

        string memory svgString = string(abi.encodePacked(
                drawTrait(traitData[0][s.background]),
                drawTrait(traitData[1][s.block]),
                drawTrait(traitData[2][s.plot]),
                drawTrait(traitData[3][s.name]),
                drawTrait(traitData[4][s.frame]),
                drawTrait(traitData[5][s.gangsters]),
                drawTrait(traitData[6][s.houses]),
                drawTrait(traitData[7][s.ground])
            ));

        return string(abi.encodePacked(
                '<svg id="gng" width="100%" height="100%" version="1.1" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                svgString,
                "</svg>"
            ));
    }

    /**
     * generates an attribute for the attributes array in the ERC721 metadata standard
     * @param traitType the trait type to reference as the metadata key
   * @param value the token's trait associated with the key
   * @return a JSON dictionary for the single attribute
   */
    function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked(
                '{"trait_type":"',
                traitType,
                '","value":"',
                value,
                '"}'
            ));
    }

    /**
     * generates an array composed of all the individual traits and values
     * @param tokenId the ID of the token to compose the metadata for
   * @return a JSON array of all of the attributes for given token ID
   */
    function compileAttributes(uint256 tokenId) public view returns (string memory) {
        IGNG.FarmBranch memory s = gng.getTokenTraits(tokenId);
        string memory traits;

        traits = string(abi.encodePacked(
                attributeForTypeAndValue(_traitTypes[0], traitData[0][s.background].name),',',
                attributeForTypeAndValue(_traitTypes[1], traitData[1][s.block].name),',',
                attributeForTypeAndValue(_traitTypes[2], traitData[2][s.plot].name),',',
                attributeForTypeAndValue(_traitTypes[3], traitData[3][s.name].name),',',
                attributeForTypeAndValue(_traitTypes[4], traitData[4][s.frame].name),',',
                attributeForTypeAndValue(_traitTypes[5], traitData[5][s.gangsters].name),',',
                attributeForTypeAndValue(_traitTypes[6], traitData[6][s.houses].name),',',
                attributeForTypeAndValue(_traitTypes[7], traitData[7][s.ground].name),',',
                attributeForTypeAndValue("Fertility", _fertility[s.fertility]),','
            ));

        return string(abi.encodePacked(
                '[',
                traits,
                '{"trait_type":"Generation","value":',
                tokenId <= gng.getPaidTokens() ? '"Gen 0"' : '"Gen 1"',
                '},{"trait_type":"Type","value":', '"Farm"',
                '}]'
            ));
    }

    /**
     * generates a base64 encoded metadata response without referencing off-chain content
     * @param tokenId the ID of the token to generate the metadata for
   * @return a base64 encoded JSON dictionary of the token's metadata and SVG
   */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        IGNG.FarmBranch memory s = gng.getTokenTraits(tokenId);

        string memory metadata = string(abi.encodePacked(
                '{"name": "',
                'Sheep #',
                tokenId.toString(),
                '", "description": "boom boom pau pau", "image": "data:image/svg+xml;base64,',
                base64(bytes(drawSVG(tokenId))),
                '", "attributes":',
                compileAttributes(tokenId),
                "}"
            ));

        return string(abi.encodePacked(
                "data:application/json;base64,",
                base64(bytes(metadata))
            ));
    }

    /** BASE 64 - Written by Brech Devos */

    string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    function base64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
        // set the actual output length
            mstore(result, encodedLen)

        // prepare the lookup table
            let tablePtr := add(table, 1)

        // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

        // result ptr, jump over length
            let resultPtr := add(result, 32)

        // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                dataPtr := add(dataPtr, 3)

            // read 3 bytes
                let input := mload(dataPtr)

            // write 4 characters
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
                resultPtr := add(resultPtr, 1)
            }

        // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }
}
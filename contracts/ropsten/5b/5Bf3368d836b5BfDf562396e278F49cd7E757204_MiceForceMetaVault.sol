// contracts/MiceForceMetaVault.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Utils.sol";

/*
  __  __      _     __      __         _ _   
 |  \/  |    | |    \ \    / /        | | |  
 | \  / | ___| |_ __ \ \  / /_ _ _   _| | |_ 
 | |\/| |/ _ \ __/ _` \ \/ / _` | | | | | __|
 | |  | |  __/ || (_| |\  / (_| | |_| | | |_ 
 |_|  |_|\___|\__\__,_| \/ \__,_|\__,_|_|\__|

*/

/**
@notice MetaVault contract used to keep all metadata separately and generate the user-friendly representation of it
*/
contract MiceForceMetaVault {
    using Utils for uint8;

    struct Trait {
        string traitName;
        string traitType;
        string pixels;
        uint8 colorsCount;
    }

    //Mappings
    mapping(uint256 => Trait[])[2] traitTypes;
    string[] internal colors;

    //string arrays
    string[26] LETTERS = [
        "a",
        "b",
        "c",
        "d",
        "e",
        "f",
        "g",
        "h",
        "i",
        "j",
        "k",
        "l",
        "m",
        "n",
        "o",
        "p",
        "q",
        "r",
        "s",
        "t",
        "u",
        "v",
        "w",
        "x",
        "y",
        "z"
    ];

    //bytes
    string collectionDescription = "MiceForce is fully onchain collection of scimice and milimice working together to resolve the Z-crisis.";
            
    //address
    address public _owner;
    address miceForce;

    constructor() {
        _owner = msg.sender;
    }

    /**
    @dev Create SVG string representation of bytes9 packed hash
    @param _packedHash 9 bytes packed hash:
        0: 0 - alive, 1 - dead
        1: 0 - military, 1 - scientist
        2-9: corresponding trait index
    */
    function hashToSVG(
        bytes9 _packedHash
    )
        public
        view
        returns (string memory)
    {
        string memory svgString;
        bool[24][24] memory placedPixels;
        string[64] memory paths;
        bool[64] memory colorsUsed;

        bytes1 dead = _packedHash[0];
        uint8 miliSci = uint8(_packedHash[1]);
        
        // iterating through every trait (except of dead or alive)
        for (uint8 i = 1; i < 9; i++) {

            // ignore if no traits was added for index
            if (traitTypes[miliSci][i].length == 0) {
                continue;
            }

            uint8 thisTraitIndex = uint8(_packedHash[i]);
            uint processed;

            // processing every color in the traits string
            for (
                uint16 j = 0;
                j < traitTypes[miliSci][i][thisTraitIndex].colorsCount;
                j++
            ) {
                string memory pixels = traitTypes[miliSci][i][thisTraitIndex].pixels;

                // read header
                // read color index
                uint8 color_index = uint8(Utils.uint16FromBytesByIndex(bytes(pixels), processed, processed+=2));

                // read pixel count
                uint pixelCount = Utils.uint16FromBytesByIndex(bytes(pixels), processed, processed+=3);

                // process every pixel
                for (uint8 pixelId=0;pixelId<pixelCount;pixelId++)
                {
                    uint8 x = uint8FromLetterByIndex(pixels, processed++);
                    uint8 y = uint8FromLetterByIndex(pixels, processed++);

                    // skip if pixel was filled already
                    if (placedPixels[x][y]) continue;

                    // definine the new path if color was not used before
                    if (!colorsUsed[color_index]) 
                    {
                            paths[color_index] = string(
                            abi.encodePacked(
                                "<path class='c",
                                color_index.toString(), 
                                "' d='"
                            )
                        );
                        colorsUsed[color_index]=true;
                    }

                    // set path coords for specific pixel
                    paths[color_index] = string(
                            abi.encodePacked(
                                paths[color_index],
                                "M",
                                x.toString(),
                                " ",
                                y.toString(), 
                                "h1"
                            )
                        );

                    placedPixels[x][y]=true;
                }
            }
        }

        // create style string
        string memory svg_tail="<style>#zmouse-svg{shape-rendering: crispedges;} ";
        for (uint8 i = 0; i < 64; i++)
        {
            if (colorsUsed[i]) 
            {
                // add used color to SVG style
                svg_tail=string(
                        abi.encodePacked(
                            svg_tail,
                            ".c",
                            i.toString(),
                            "{stroke:#",
                            colors[i],
                            "}"
                        )
                );
                // add path to SVG
                svgString=string(
                        abi.encodePacked(
                            svgString,
                            paths[i],
                            "'/>"
                        )
                );
            }
        }

        // create final SVG string
        svgString = string(
            abi.encodePacked(
                '<svg id="zmouse-svg" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 24 24">',
                //add saturation filter if miceforce unit is dead
                dead==0x01?'<filter id="dead"><feColorMatrix type="saturate" values="0"/></filter><g filter="url(#dead)">':'',
                svgString,dead==0x01?'</g>':'',
                svg_tail,"</style></svg>"
            )
        );

        return svgString;
    }

    /**
    @dev Generate traits JSON array
    @param _packedHash 9 bytes packed hash:
        0: 0 - alive, 1 - dead
        1: 0 - military, 1 - scientist
        2-9: corresponding trait index
    */
    function hashToMetadata(
        bytes9 _packedHash
    )
        public
        view
        returns (string memory)
    {
        string memory metadataString;

        uint16 miliSci  = uint8(_packedHash[1]);
        
        // iterating through every trait (including dead or alive)
        for (uint8 i = 0; i < 9; i++) {
            // ignore if trait was not added
            if (traitTypes[miliSci][i].length == 0) {
                continue;
            }
            uint8 thisTraitIndex = uint8(_packedHash[i]);

            metadataString = string(
                abi.encodePacked(
                    metadataString,
                    '{"trait_type":"',
                    traitTypes[miliSci][i][thisTraitIndex].traitType,
                    '","value":"',
                    traitTypes[miliSci][i][thisTraitIndex].traitName,
                    '"}'
                )
            );
            
            // add comma if it's not last element of traits array
            if (i != 8)
                metadataString = string(abi.encodePacked(metadataString, ","));
        }

        return string(abi.encodePacked("[", metadataString, "]"));
    }

    /**
    @dev Generate base64 encoded string of metadata JSON array including base64 encoded SVG string and traits JSON 
    @param _id MiceForce unit id
    @param _packedHash 9 bytes packed hash:
        0: 0 - alive, 1 - dead
        1: 0 - military, 1 - scientist
        2-9: corresponding trait index
     */
    function getMetadataByHash(
        uint _id, bytes9 _packedHash
    )
        external
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Utils.encode(
                        bytes(
                            string(
                                abi.encodePacked(
                                    '{"name": "MiceForce #',
                                    Utils.toString(_id),
                                    '", "description":"',collectionDescription,'","image": "data:image/svg+xml;base64,',
                                    Utils.encode(
                                        bytes(hashToSVG(_packedHash))
                                    ),
                                    '","attributes":',
                                    hashToMetadata(_packedHash),
                                    "}"
                                )
                            )
                        )
                    )
                )
            );
    }


    /*
   ____                                         _       
  / __ \                                       | |      
 | |  | |_      ___ __   ___ _ __    ___  _ __ | |_   _ 
 | |  | \ \ /\ / / '_ \ / _ \ '__|  / _ \| '_ \| | | | |
 | |__| |\ V  V /| | | |  __/ |    | (_) | | | | | |_| |
  \____/  \_/\_/ |_| |_|\___|_|     \___/|_| |_|_|\__, |
                                                   __/ |
                                                  |___/  
    */

    /**
    @dev Clears the traits array for specific MiceForce unit type
    @param _miliSci MiceForce type index: 0 - Military, 1 - Scientist
    */
    function clearTraits(
        uint8 _miliSci
    ) 
        external 
        onlyOwner 
    {
        for (uint256 i = 0; i < 9; i++) {
            delete traitTypes[_miliSci][i];
        }
    }

    /**
    @dev Add a traits
    @param _miliSci MiceForce type index: 0 - Military, 1 - Scientist
    @param _traitTypeIndex Trait type index
    @param _traits Array of traits to add
    */

    function addTraitType(
        uint8 _miliSci,
        uint256 _traitTypeIndex,
        Trait[] memory _traits
    )
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _traits.length; i++) {
            traitTypes[_miliSci][_traitTypeIndex].push(
                Trait(
                    _traits[i].traitName,
                    _traits[i].traitType,
                    _traits[i].pixels,
                    _traits[i].colorsCount
                )
            );
        }

        return;
    }

    /**
    @dev Get uint8 representation of letter from string by index
    @param _string String to get letter from
    @param _index Letter index within the string
    */
    function uint8FromLetterByIndex(string memory _string, uint _index) internal pure returns(uint8) {
        bytes memory strBytes = bytes(_string);
        return uint8(strBytes[_index])-96;
    }

    /**
    @dev Set all colors to be used during SVG generation, their order should be the same as during the pixel metadata generation
    @param _colors Colors hex representation array
    */
    function setColors(
        string[] memory _colors
    ) 
        external 
        onlyOwner 
    {
        colors=_colors;
    }

    /**
    @dev Set description to be used in every item metadata
    @param _collectionDescription Description string
    */
    function setCollectionDescription(
        string memory _collectionDescription
    ) 
        external 
        onlyOwner 
    {
        collectionDescription = _collectionDescription;
    }

    /**
    @dev Set the address of MiceForce contract
    @param _contract MF contract address
    */
    function setMFContract(address _contract) external onlyOwner{
        miceForce=_contract;
    }

    // add to allow function be called from owner address only
    modifier onlyOwner() {
        require(_owner == msg.sender);
        _;
    }
}
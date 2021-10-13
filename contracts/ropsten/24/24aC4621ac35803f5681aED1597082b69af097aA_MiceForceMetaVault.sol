// contracts/MiceForceMetaVault.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./ZombiemiceUtils.sol";

contract MiceForceMetaVault {
    using ZombiemiceUtils for uint8;

    struct Trait {
        string traitName;
        string traitType;
        string pixels;
        uint256 colorsCount;
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
    bytes collectionDescription = "MiceForce is fully onchain collection of scimice and milimice working together to resolve the Z-crisis.";
            
    //address
    address public _owner;
    address miceForce;

    constructor() {
        _owner = msg.sender;
    }

    /**
     * @dev Helper function to reduce pixel size within contract
     */
    function letterToNumber(
        string memory _inputLetter
    )
        internal
        view
        returns (uint8)
    {
        for (uint8 i = 0; i < LETTERS.length; i++) {
            if (
                keccak256(abi.encodePacked((LETTERS[i]))) ==
                keccak256(abi.encodePacked((_inputLetter)))
            ) return (i + 1);
        }
        revert();
    }


    // Credits goes to Anonymice, I've just optimized this a bit in terms of generated SVG size and stored data size
    function hashToSVG(
        string memory _hash
    )
        public
        view
        returns (string memory)
    {
        string memory svgString;
        bool[24][24] memory placedPixels;
        string[128] memory paths;
        bool[128] memory colorsUsed;

        uint8 milliSci = ZombiemiceUtils.parseInt(
                ZombiemiceUtils.substring(_hash, 0, 1)
            );

        // itterating every trait except of the first one (milisci due it have no pixel representation)
        for (uint8 i = 0; i < 9; i++) {
            // ignore if no traits was added for index
            if (traitTypes[milliSci][i].length == 0) {
                continue;
            }
            uint8 thisTraitIndex = ZombiemiceUtils.parseInt(
                ZombiemiceUtils.substring(_hash, i, i + 1)
            );
            uint processed;
            // processing every color in the traits string
            for (
                uint16 j = 0;
                j < traitTypes[milliSci][i][thisTraitIndex].colorsCount;
                j++
            ) {
                
                // read header
                // read color index
                uint8 color_index = ZombiemiceUtils.parseInt(
                        ZombiemiceUtils.substring(
                        traitTypes[milliSci][i][thisTraitIndex].pixels,
                        processed,
                        processed+=2
                    )
                );
                //processed+=2;

                // read pixel count
                uint pixelCount = ZombiemiceUtils.parseInt(ZombiemiceUtils.substring(
                    traitTypes[milliSci][i][thisTraitIndex].pixels,
                    processed,
                    processed+=3
                ));
                //processed+=3;

                // process every pixel
                for (uint8 pixelId=0;pixelId<pixelCount;pixelId++)
                {
                    uint8 x = letterToNumber(
                        ZombiemiceUtils.substring(traitTypes[milliSci][i][thisTraitIndex].pixels, processed, processed+=1)
                    );
                    //processed++;

                    uint8 y = letterToNumber(
                        ZombiemiceUtils.substring(traitTypes[milliSci][i][thisTraitIndex].pixels, processed, processed+=1)
                    );
                    //processed++;

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

                    // set path data for specific pixel
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
        string memory svg_tail="<style>#mouse-svg{shape-rendering: crispedges;} ";
        for (uint8 i = 0; i < 128; i++)
        {
            if (colorsUsed[i]) 
            {
                // add used color to the style
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
                // add the path to SVG
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
                '<svg id="zmouse-svg" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 24 24"> ',
                svgString,
                svg_tail,
                "</style></svg>"
            )
        );

        return svgString;
    }

    /**
     * @dev Hash to metadata function
     */
    function hashToMetadata(
        string memory _hash
    )
        public
        view
        returns (string memory)
    {
        string memory metadataString;

        uint8 milliSci  = ZombiemiceUtils.parseInt(
                ZombiemiceUtils.substring(_hash, 0, 1)
            );

        for (uint8 i = 0; i < 9; i++) {
            // ignore if trait was not added
            if (traitTypes[milliSci][i].length == 0) {
                continue;
            }
            uint8 thisTraitIndex = ZombiemiceUtils.parseInt(
                ZombiemiceUtils.substring(_hash, i, i + 1)
            );

            metadataString = string(
                abi.encodePacked(
                    metadataString,
                    '{"trait_type":"',
                    traitTypes[milliSci][i][thisTraitIndex].traitType,
                    '","value":"',
                    traitTypes[milliSci][i][thisTraitIndex].traitName,
                    '"}'
                )
            );

            if (i != 8)
                metadataString = string(abi.encodePacked(metadataString, ","));
        }

        return string(abi.encodePacked("[", metadataString, "]"));
    }

    /**
     * @dev Returns the SVG and metadata for a token Id
     * @param _hash The tokenId to return the SVG and metadata for.
     */
    function getMetadataByHash(
        uint _id, string memory _hash
    )
        external
        view
        returns (string memory)
    {
        string memory tokenHash = _hash;

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    ZombiemiceUtils.encode(
                        bytes(
                            string(
                                abi.encodePacked(
                                    '{"name": "MiceForce #',
                                    ZombiemiceUtils.toString(_id),
                                    '", "description":"',collectionDescription,'","image": "data:image/svg+xml;base64,',
                                    ZombiemiceUtils.encode(
                                        bytes(hashToSVG(tokenHash))
                                    ),
                                    '","attributes":',
                                    hashToMetadata(tokenHash),
                                    "}"
                                )
                            )
                        )
                    )
                )
            );
    }


    /*
      _____                                         _       
     / ___ \                                       | |      
    | |   | |_ _ _ ____   ____  ____     ___  ____ | |_   _ 
    | |   | | | | |  _ \ / _  )/ ___)   / _ \|  _ \| | | | |
    | |___| | | | | | | ( (/ /| |      | |_| | | | | | |_| |
     \_____/ \____|_| |_|\____)_|       \___/|_| |_|_|\__  |
                                                      (____/ 
    */

    /**
     * @dev Clears the traits.
     */
    function clearTraits(
        uint8 milliSci
    ) 
        external 
        onlyOwner 
    {
        for (uint256 i = 0; i < 9; i++) {
            delete traitTypes[milliSci][i];
        }
    }

    /**
     * @dev Add a trait type
     * @param _traitTypeIndex The trait type index
     * @param _traits Array of traits to add
     */

    function addTraitType(
        uint8 milliSci,
        uint256 _traitTypeIndex,
        Trait[] memory _traits
    )
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _traits.length; i++) {
            traitTypes[milliSci][_traitTypeIndex].push(
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
     * @dev Set the SVG classes colors
     * @param _colors colors used in collection
     */
    function setColors(
        string[] memory _colors
    ) 
        external 
        onlyOwner 
    {
        colors=_colors;
    }

    /*
     * @dev Set the every item description
     * @param _collectionDescription The description string
     */
     /*
    function setCollectionDescription(
        string memory _collectionDescription
    ) 
        external 
        onlyOwner 
    {
        collectionDescription = _collectionDescription;
    }
    */

    function setMFContract(address _contract) external onlyOwner{
        miceForce=_contract;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender);
        _;
    }

    // add to make metadata retrieval accessible for MF contract only
    modifier onlyMiceForceContract() {
        require(miceForce == msg.sender);
        _;
    }
}
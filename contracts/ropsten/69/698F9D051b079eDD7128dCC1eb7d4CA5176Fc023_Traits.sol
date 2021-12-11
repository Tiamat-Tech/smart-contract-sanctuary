//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";

import "./Randomizer.sol";
import "./ICryptoBees.sol";
import "./IHoney.sol";
import "./Base64.sol";

contract Traits is Ownable {
    using Strings for uint256;
    using MerkleProof for bytes32[];
    // struct to store each trait's data for metadata and rendering
    struct Trait {
        string name;
        string png;
    }
    ICryptoBees beesContract;
    IHoney honeyContract;
    Randomizer randomizerContract;
    // mint price ETH
    uint256 public constant MINT_PRICE = .02 ether;
    uint256 public constant MINT_PRICE_DISCOUNT = .055 ether;

    // mint price HONEY
    uint256 public constant MINT_PRICE_HONEY = 3000 ether;
    // mint price WOOL
    uint256 public mintPriceWool = 3000 ether;
    // max number of tokens that can be minted
    uint256 public constant MAX_TOKENS = 40000;
    // number of tokens that can be claimed for ETH
    uint256 public constant PAID_TOKENS = 10000;
    /// @notice controls if mintWithEthPresale is paused
    bool public mintWithEthPresalePaused = true;
    /// @notice controls if mintWithWool is paused
    bool public mintWithWoolPaused = true;

    bytes32 private merkleRootWhitelist;

    string[9] _traitTypes = ["Fur", "Head", "Ears", "Eyes", "Nose", "Mouth", "Neck", "Feet", "Alpha"];
    // storage of each traits name and base64 PNG data
    mapping(uint8 => mapping(uint8 => Trait)) public traitData;
    // mapping from alphaIndex to its score
    string[4] _alphas = ["8", "7", "6", "5"];
    // 0 - 9 are associated with Sheep, 10 - 18 are associated with Wolves
    uint8[][18] public rarities;
    // list of aliases for Walker's Alias algorithm
    // 0 - 9 are associated with Sheep, 10 - 18 are associated with Wolves
    uint8[][18] public aliases;

    constructor() {
        // I know this looks weird but it saves users gas by making lookup O(1)
        // A.J. Walker's Alias Algorithm
        // sheep
        // fur
        // rarities[0] = [15, 50, 200, 250, 255];
        // aliases[0] = [4, 4, 4, 4, 4];
        // // head
        // rarities[1] = [190, 215, 240, 100, 110, 135, 160, 185, 80, 210, 235, 240, 80, 80, 100, 100, 100, 245, 250, 255];
        // aliases[1] = [1, 2, 4, 0, 5, 6, 7, 9, 0, 10, 11, 17, 0, 0, 0, 0, 4, 18, 19, 19];
        // // ears
        // rarities[2] = [255, 30, 60, 60, 150, 156];
        // aliases[2] = [0, 0, 0, 0, 0, 0];
        // // eyes
        // rarities[3] = [221, 100, 181, 140, 224, 147, 84, 228, 140, 224, 250, 160, 241, 207, 173, 84, 254, 220, 196, 140, 168, 252, 140, 183, 236, 252, 224, 255];
        // aliases[3] = [1, 2, 5, 0, 1, 7, 1, 10, 5, 10, 11, 12, 13, 14, 16, 11, 17, 23, 13, 14, 17, 23, 23, 24, 27, 27, 27, 27];
        // // nose
        // rarities[4] = [175, 100, 40, 250, 115, 100, 185, 175, 180, 255];
        // aliases[4] = [3, 0, 4, 6, 6, 7, 8, 8, 9, 9];
        // // mouth
        // rarities[5] = [80, 225, 227, 228, 112, 240, 64, 160, 167, 217, 171, 64, 240, 126, 80, 255];
        // aliases[5] = [1, 2, 3, 8, 2, 8, 8, 9, 9, 10, 13, 10, 13, 15, 13, 15];
        // // neck
        // rarities[6] = [255];
        // aliases[6] = [0];
        // // feet
        // rarities[7] = [243, 189, 133, 133, 57, 95, 152, 135, 133, 57, 222, 168, 57, 57, 38, 114, 114, 114, 255];
        // aliases[7] = [1, 7, 0, 0, 0, 0, 0, 10, 0, 0, 11, 18, 0, 0, 0, 1, 7, 11, 18];
        // // alphaIndex
        // rarities[8] = [255];
        // aliases[8] = [0];
        // wolves
        // fur
        // rarities[9] = [210, 90, 9, 9, 9, 150, 9, 255, 9];
        // aliases[9] = [5, 0, 0, 5, 5, 7, 5, 7, 5];
        // // head
        // rarities[10] = [255];
        // aliases[10] = [0];
        // // ears
        // rarities[11] = [255];
        // aliases[11] = [0];
        // // eyes
        // rarities[12] = [135, 177, 219, 141, 183, 225, 147, 189, 231, 135, 135, 135, 135, 246, 150, 150, 156, 165, 171, 180, 186, 195, 201, 210, 243, 252, 255];
        // aliases[12] = [1, 2, 3, 4, 5, 6, 7, 8, 13, 3, 6, 14, 15, 16, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 26, 26];
        // // nose
        // rarities[13] = [255];
        // aliases[13] = [0];
        // // mouth
        // rarities[14] = [239, 244, 249, 234, 234, 234, 234, 234, 234, 234, 130, 255, 247];
        // aliases[14] = [1, 2, 11, 0, 11, 11, 11, 11, 11, 11, 11, 11, 11];
        // // neck
        // rarities[15] = [75, 180, 165, 120, 60, 150, 105, 195, 45, 225, 75, 45, 195, 120, 255];
        // aliases[15] = [1, 9, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 14, 12, 14];
        // // feet
        // rarities[16] = [255];
        // aliases[16] = [0];
        // // alphaIndex
        // rarities[17] = [8, 160, 73, 255];
        // aliases[17] = [2, 3, 3, 3];
        // seed >>= 16;
        // console.log("hovno:", (seed & 0xFFFF), selectTrait(uint16(seed & 0xFFFF), 1));
        // seed >>= 16;
        // console.log("hovno::", (seed & 0xFFFF), selectTrait(uint16(seed & 0xFFFF), 2));
    }

    function setContracts(address _BEES, address _HONEY) external onlyOwner {
        honeyContract = IHoney(_HONEY);
        beesContract = ICryptoBees(_BEES);
    }

    /** MINTING */
    function mintForEth(
        address addr,
        uint256 amount,
        uint256 minted,
        uint256 value
    ) external {
        require(_msgSender() == address(beesContract), "DONT CHEAT!");
        mintCheck(addr, amount, minted, false, value, true);
        for (uint256 i = 1; i <= amount; i++) {
            mint(addr, minted + i);
        }
    }

    function mintForEthWhitelist(
        address addr,
        uint256 amount,
        uint256 minted,
        uint256 value,
        bytes32[] calldata _merkleProof
    ) external {
        require(_msgSender() == address(beesContract), "DONT CHEAT!");
        bytes32 leaf = keccak256(abi.encodePacked(addr));
        require(MerkleProof.verify(_merkleProof, merkleRootWhitelist, leaf), "You are not on the whitelist!");
        mintCheck(addr, amount, minted, true, value, true);
        for (uint256 i = 1; i <= amount; i++) {
            mint(addr, minted + i);
        }
    }

    function mintForHoney(
        address addr,
        uint256 amount,
        uint256 minted
    ) external {
        require(_msgSender() == address(beesContract), "DONT CHEAT!");
        mintCheck(addr, amount, minted, false, 0, false);
        uint256 totalHoneyCost = 0;
        for (uint256 i = 1; i <= amount; i++) {
            totalHoneyCost += mintCost(minted + i);
            mint(addr, minted + i);
        }
        honeyContract.burn(addr, totalHoneyCost);
    }

    function mintForWool(
        address addr,
        uint256 amount,
        uint256 minted
    ) external returns (uint256 totalWoolCost) {
        require(_msgSender() == address(beesContract), "DONT CHEAT!");
        require(!mintWithWoolPaused, "WOOL minting paused");
        require(minted + amount <= PAID_TOKENS, "All tokens on-sale already sold");
        mintCheck(addr, amount, minted, false, 0, false);

        for (uint256 i = 1; i <= amount; i++) {
            totalWoolCost += mintPriceWool;
            mint(addr, minted + i);
        }
    }

    function mint(address addr, uint256 minted) private {
        beesContract.mint(addr, minted);
    }

    function mintCheck(
        address addr,
        uint256 amount,
        uint256 minted,
        bool presale,
        uint256 value,
        bool isEth
    ) private view {
        require(tx.origin == addr, "Only EOA");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        if (presale) {
            require(!mintWithEthPresalePaused, "Presale mint paused");
            require(amount > 0 && amount <= 2, "Invalid mint amount presale");
        } else require(amount > 0 && amount <= 10, "Invalid mint amount sale");
        if (isEth) {
            require(minted + amount <= PAID_TOKENS, "All tokens on-sale already sold");
            if (presale) require(amount * MINT_PRICE_DISCOUNT == value, "Invalid payment amount presale");
            else require(amount * MINT_PRICE == value, "Invalid payment amount sale");
        }
    }

    function getTokenTextType(uint256 tokenId) external view returns (string memory) {
        require(beesContract.doesExist(tokenId), "ERC721Metadata: Nonexistent token");
        return _getTokenTextType(tokenId);
    }

    function _getTokenTextType(uint256 tokenId) private view returns (string memory) {
        uint8 _type = beesContract.getTokenData(tokenId)._type;
        if (_type == 1) return "BEE";
        else if (_type == 2) return "BEAR";
        else if (_type == 3) return "BEEKEEPER";
        else return "NOT REVEALED";
    }

    function _getTokenImage(uint256 tokenId) private view returns (string memory) {
        uint8 _type = beesContract.getTokenData(tokenId)._type;
        if (_type == 1) return "QmfCnnjNDndTuRZLZFJhLVtQ8m533pEnBis4Y2NH3BvZdF";
        else if (_type == 2) return "QmVPMv3Kxg94vAJo4fQY2FGnYTYp4RM1dq7anwr9psbz9P";
        else if (_type == 3) return "QmTUuGDbndWZDYYr6pE1aeutZLpSuZi44KMZxeUw1VB2D8";
        else return "";
    }

    function setPresaleMintPaused(bool _paused) external onlyOwner {
        mintWithEthPresalePaused = _paused;
    }

    function setWoolMintPaused(bool _paused) external onlyOwner {
        mintWithWoolPaused = _paused;
    }

    function setWoolMintPrice(uint256 _price) external onlyOwner {
        mintPriceWool = _price;
    }

    function setMerkleRoot(bytes32 root) public onlyOwner {
        merkleRootWhitelist = root;
    }

    /**
     * Gen 0 can be mint for honey too
     * @param tokenId the ID to check the cost of to mint
     * @return the cost of the given token ID
     */
    function mintCost(uint256 tokenId) public pure returns (uint256) {
        if (tokenId <= 20000) return MINT_PRICE_HONEY;
        if (tokenId <= 30000) return 7500 ether;
        return 15000 ether;
    }

    /**
     * administrative to upload the names and images associated with each trait
     * @param traitType the trait type to upload the traits for (see traitTypes for a mapping)
     * @param traitNames the names and base64 encoded PNGs for each trait
     * @param traitImages the names and base64 encoded PNGs for each trait
     */
    function uploadTraits(
        uint8 traitType,
        uint8[] calldata traitIds,
        string[] calldata traitNames,
        string[] calldata traitImages
    ) external onlyOwner {
        require(traitIds.length == traitNames.length, "Mismatched inputs");
        require(traitIds.length == traitImages.length, "Mismatched inputs");
        for (uint256 i = 0; i < traitIds.length; i++) {
            traitData[traitType][traitIds[i]] = Trait(traitNames[i], traitImages[i]);
        }
    }

    function selectTrait(uint16 seed, uint8 traitType) internal view returns (uint8) {
        uint8 trait = uint8(seed) % uint8(rarities[traitType].length);
        console.log(">>", seed, trait);
        console.log(">>", seed >> 8, rarities[traitType][trait]);
        if (seed >> 8 < rarities[traitType][trait]) return trait;
        return aliases[traitType][trait];
    }

    function random(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tx.origin, block.number, block.timestamp, seed)));
    }

    /** RENDER */

    /**
     * generates an <image> element using base64 encoded PNGs
     * @param trait the trait storing the PNG data
     * @return the <image> element
     */
    function drawTrait(Trait memory trait) internal pure returns (string memory) {
        if (bytes(trait.png).length == 0) return "";
        return
            string(
                abi.encodePacked(
                    '<image x="4" y="4" width="32" height="32" image-rendering="pixelated" preserveAspectRatio="xMidYMid" xlink:href="data:image/png;base64,',
                    trait.png,
                    '"/>'
                )
            );
    }

    // /**
    //  * generates an entire SVG by composing multiple <image> elements of PNGs
    //  * @param tokenId the ID of the token to generate an SVG for
    //  * @return a valid SVG of the Sheep / Wolf
    //  */
    function drawSVG(
        uint8 color,
        uint8 eyes,
        uint8 feelers,
        uint8 hair,
        uint8 mouth,
        uint8 nose,
        uint8 accessories
    ) public view returns (string memory) {
        // IWoolf.SheepWolf memory s = woolf.getTokenTraits(tokenId);
        uint8 shift = 0;

        string memory svgString = string(
            abi.encodePacked(
                drawTrait(traitData[0 + shift][0]),
                drawTrait(traitData[1 + shift][color]),
                drawTrait(traitData[2 + shift][eyes]),
                drawTrait(traitData[3 + shift][feelers]),
                drawTrait(traitData[4 + shift][hair]),
                drawTrait(traitData[5 + shift][mouth]),
                drawTrait(traitData[6 + shift][nose]),
                drawTrait(traitData[7 + shift][accessories])
            )
        );

        return
            string(
                abi.encodePacked(
                    '<svg id="woolf" width="100%" height="100%" version="1.1" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                    svgString,
                    "</svg>"
                )
            );
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(beesContract.doesExist(tokenId), "ERC721Metadata: Nonexistent token");

        string memory textType = ""; //_getTokenTextType(tokenId);
        string memory metadata = string(
            abi.encodePacked(
                '{"name": "',
                textType,
                " #",
                uint256(tokenId).toString(),
                '", "type": "',
                textType,
                // '", "trait": "',
                // uint256(beesContract.getTokenData(tokenId)._type).toString(),
                '", "description": "',
                '","image": "data:image/svg+xml;base64,',
                Base64.encode(bytes(drawSVG(0, 0, 0, 3, 3, 5, 0))),
                '"}'
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata))));
    }
}
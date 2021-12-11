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

    // used to ensure there are no duplicates
    mapping(uint256 => uint256) public existingCombinations;

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

    string[8] _traitTypes = ["Body", "Color", "Eyes", "Mouth", "Nose", "Hair", "Accessories", "Feelers"];
    // storage of each traits name and base64 PNG data
    mapping(uint8 => mapping(uint8 => Trait)) public traitData;
    // mapping from alphaIndex to its score
    string[4] _alphas = ["8", "7", "6", "5"];
    // 0 - 7 are associated with Bees, 8 - 18 are associated with Bears
    uint8[][22] public rarities;
    // 0 - 7 are associated with Bees, 8 - 18 are associated with Bears
    uint8[][22] public aliases;

    constructor() {
        // colours
        rarities[1] = [255, 215, 122, 76, 30, 15];
        aliases[1] = [0, 0, 0, 0, 0, 0];
        // eyes
        rarities[2] = [255, 217, 217, 230, 217, 204, 230, 230, 230, 230, 230, 191, 191, 191, 191];
        aliases[2] = [0, 0, 1, 2, 3, 4, 0, 0, 0, 0, 0, 1, 1, 2, 5];
        // mouth
        rarities[3] = [255, 202, 191, 181, 215, 248, 199, 194, 189, 184, 179, 217, 174, 174, 174, 174, 174];
        aliases[3] = [0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 10];
        // nose
        rarities[4] = [255, 230, 204, 192, 179, 179, 179];
        aliases[4] = [0, 0, 1, 2, 0, 1, 3];
        // hair
        rarities[5] = [255, 127, 204, 230, 115, 115, 115, 115, 115];
        aliases[5] = [0, 0, 1, 0, 0, 0, 1, 1, 2];
        // accessory
        rarities[6] = [255, 99, 53];
        aliases[6] = [0, 0, 0];
        // feelers
        rarities[7] = [255, 140, 204, 102, 179, 89, 89];
        aliases[7] = [0, 0, 1, 2, 0, 1, 3];

        //bear - colours
        rarities[9] = [255, 153, 153];
        aliases[9] = [0, 0, 0];

        //bear - eyes
        rarities[10] = [255, 220, 184, 148, 222, 186, 151, 225, 189, 153, 117, 240, 204, 168, 133, 145, 145, 97, 97];
        aliases[10] = [0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 3, 6, 10, 14];

        //bear - mouth
        rarities[11] = [255, 235, 184, 204, 225, 174, 245, 245, 245, 184, 184, 122];
        aliases[11] = [0, 0, 1, 2, 3, 4, 0, 0, 0, 2, 3, 5];

        //bear - nose
        rarities[12] = [255, 230, 204, 179, 179, 179, 179];
        aliases[12] = [0, 0, 1, 0, 1, 2, 2];

        //bear - hat/hair
        rarities[13] = [255, 204, 204, 204, 102, 102, 102, 102];
        aliases[13] = [0, 0, 0, 0, 0, 0, 0, 0];

        //bear - accessory
        rarities[14] = [255, 89, 89, 53, 53, 35, 35];
        aliases[14] = [0, 0, 0, 0, 0, 0, 0];

        //beekeeper - color
        rarities[16] = [255, 153, 153, 153, 76, 76];
        aliases[16] = [0, 0, 0, 0, 0, 0];

        //beekeeper - eyes
        rarities[17] = [255, 170, 142, 113];
        aliases[17] = [0, 0, 1, 2];

        //beekeeper - mouth
        rarities[18] = [255, 243, 230, 217, 204, 192, 179];
        aliases[18] = [0, 0, 1, 2, 3, 4, 5];

        //beekeeper - hair
        rarities[20] = [255, 230, 230, 230, 230, 230, 230, 230, 230];
        aliases[20] = [0, 0, 0, 0, 0, 0, 0, 0, 0];

        //beekeeper - accessory
        rarities[21] = [255, 122, 122, 122, 122, 122, 122, 122, 122, 122, 92, 30];
        aliases[21] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
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
        // require(_msgSender() == address(beesContract), "DONT CHEAT!");
        mintCheck(addr, amount, minted, false, 0, false);
        uint256 totalHoneyCost = 0;
        for (uint256 i = 1; i <= amount; i++) {
            totalHoneyCost += mintCost(minted + i);
            mint(addr, minted + i);
        }
        // honeyContract.burn(addr, totalHoneyCost);
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
        uint256 seed = random(minted);
        generate(minted, seed);
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
     * generates traits for a specific token, checking to make sure it's unique
     * @param tokenId the id of the token to generate traits for
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t - a struct of traits for the given token ID
     */
    function generate(uint256 tokenId, uint256 seed) internal returns (ICryptoBees.Token memory t) {
        t = selectTraits(seed);
        if (existingCombinations[structToHash(t)] == 0) {
            beesContract.setTokenData(tokenId, t);
            existingCombinations[structToHash(t)] = tokenId;
            return t;
        }
        return generate(tokenId, random(seed));
    }

    /**
     * selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(uint256 seed) internal view returns (ICryptoBees.Token memory t) {
        uint256 num = ((seed & 0xFFFF) % 100);
        t._type = 1;
        if (num == 0) t._type = 3;
        else if (num < 10) t._type = 2;
        uint8 shift = t._type > 0 ? ((t._type - 1) * 7) : 0;

        seed >>= 16;
        t.color = selectTrait(uint16(seed & 0xFFFF), 1 + shift);
        seed >>= 16;
        t.eyes = selectTrait(uint16(seed & 0xFFFF), 2 + shift);
        seed >>= 16;
        t.mouth = selectTrait(uint16(seed & 0xFFFF), 3 + shift);
        if (t._type != 2) {
            seed >>= 16;
            t.nose = selectTrait(uint16(seed & 0xFFFF), 4 + shift);
        }
        seed >>= 16;
        t.hair = selectTrait(uint16(seed & 0xFFFF), 5 + shift);
        seed >>= 16;
        t.accessory = selectTrait(uint16(seed & 0xFFFF), 6 + shift);
        if (t._type == 1) {
            seed >>= 16;
            t.feelers = selectTrait(uint16(seed & 0xFFFF), 7);
        }
        console.log("type", t._type);
        console.log("color", t.color);
        console.log("eyes", t.eyes);
        console.log("mouth", t.mouth);
        console.log("nose", t.nose);
        console.log("hair", t.hair);
        console.log("accessory", t.accessory);
        console.log("feelers", t.feelers);
        // seed >>= 16;
        // t.alphaIndex = selectTrait(uint16(seed & 0xFFFF), 8 + shift);
    }

    /**
     * uses A.J. Walker's Alias algorithm for O(1) rarity table lookup
     * ensuring O(1) instead of O(n) reduces mint cost by more than 50%
     * probability & alias tables are generated off-chain beforehand
     * @param seed portion of the 256 bit seed to remove trait correlation
     * @param traitType the trait type to select a trait for
     * @return the ID of the randomly selected trait
     */
    function selectTrait(uint16 seed, uint8 traitType) internal view returns (uint8) {
        uint8 trait = uint8(seed) % uint8(rarities[traitType].length);
        if (seed >> 8 < rarities[traitType][trait]) return trait;
        return aliases[traitType][trait];
    }

    /**
     * converts a struct to a 256 bit hash to check for uniqueness
     * @param t the struct to pack into a hash
     * @return the 256 bit hash of the struct
     */
    function structToHash(ICryptoBees.Token memory t) internal pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(t._type, t.color, t.eyes, t.mouth, t.nose, t.hair, t.accessory, t.feelers, t.strength)));
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
        string[] calldata traitNames,
        string[] calldata traitImages
    ) external onlyOwner {
        require(traitNames.length == traitImages.length, "Mismatched inputs");
        for (uint256 i = 0; i < traitNames.length; i++) {
            traitData[traitType][uint8(i)] = Trait(traitNames[i], traitImages[i]);
        }
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
    function drawSVG(uint256 tokenId) public view returns (string memory) {
        ICryptoBees.Token memory s = beesContract.getTokenData(tokenId);
        uint8 shift = s._type > 0 ? ((s._type - 1) * 7) : 0;

        string memory svgString = string(
            abi.encodePacked(
                drawTrait(traitData[0][0]),
                drawTrait(traitData[1 + shift][s.color]),
                drawTrait(traitData[2 + shift][s.eyes]),
                drawTrait(traitData[3 + shift][s.mouth]),
                drawTrait(traitData[4 + shift][s.nose]),
                drawTrait(traitData[5 + shift][s.hair]),
                drawTrait(traitData[6 + shift][s.accessory]),
                drawTrait(traitData[7][s.feelers])
            )
        );

        return
            string(
                abi.encodePacked(
                    '<svg id="cryptobees" width="100%" height="100%" version="1.1" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                    svgString,
                    "</svg>"
                )
            );
    }

    /**
     * generates an attribute for the attributes array in the ERC721 metadata standard
     * @param traitType the trait type to reference as the metadata key
     * @param value the token's trait associated with the key
     * @return a JSON dictionary for the single attribute
     */
    function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked('{"trait_type":"', traitType, '","value":"', value, '"}'));
    }

    /**
     * generates an array composed of all the individual traits and values
     * @param tokenId the ID of the token to compose the metadata for
     * @return a JSON array of all of the attributes for given token ID
     */
    function compileAttributes(uint256 tokenId) public view returns (string memory) {
        ICryptoBees.Token memory t = beesContract.getTokenData(tokenId);
        string memory textType = _getTokenTextType(tokenId);
        uint8 shift = t._type > 0 ? ((t._type - 1) * 7) : 0;
        string memory traits;
        traits = string(
            abi.encodePacked(
                attributeForTypeAndValue(_traitTypes[1 + shift], traitData[1 + shift][t.color].name),
                ",",
                attributeForTypeAndValue(_traitTypes[2 + shift], traitData[2 + shift][t.eyes].name),
                ",",
                attributeForTypeAndValue(_traitTypes[3 + shift], traitData[3 + shift][t.mouth].name),
                ",",
                attributeForTypeAndValue(_traitTypes[5 + shift], traitData[5 + shift][t.hair].name),
                ",",
                attributeForTypeAndValue(_traitTypes[6 + shift], traitData[6 + shift][t.accessory].name),
                ","
            )
        );
        if (t._type != 2) {
            traits = string(abi.encodePacked(traits, attributeForTypeAndValue(_traitTypes[4 + shift], traitData[4 + shift][t.nose].name), ","));
        }
        if (t._type == 1) {
            traits = string(abi.encodePacked(traits, attributeForTypeAndValue(_traitTypes[7], traitData[7][t.feelers].name), ","));
        }

        return
            string(
                abi.encodePacked(
                    "[",
                    traits,
                    '{"trait_type":"Generation","value":',
                    tokenId <= PAID_TOKENS ? '"Gen 0"' : '"Gen 1"',
                    '},{"trait_type":"Type","value":',
                    textType,
                    "}]"
                )
            );
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        // require(beesContract.doesExist(tokenId), "ERC721Metadata: Nonexistent token");

        string memory textType = _getTokenTextType(tokenId);
        string memory metadata = string(
            abi.encodePacked(
                '{"name": "',
                textType,
                " #",
                uint256(tokenId).toString(),
                '", "type": "',
                textType,
                '", "description": "',
                '","image": "data:image/svg+xml;base64,',
                Base64.encode(bytes(drawSVG(tokenId))),
                '","attributes":',
                compileAttributes(tokenId),
                "}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata))));
    }
}
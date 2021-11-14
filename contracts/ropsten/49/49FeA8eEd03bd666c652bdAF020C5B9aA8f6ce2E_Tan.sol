// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

//contract Tan is ERC721URIStorage, Ownable {
contract Tan is ERC721, Ownable {
    using Strings for uint8;
    using Strings for uint16;
    using Strings for uint256;

    uint256 public tokenCounter;
    uint16 tokenCounterWhitelist;

    event MintedTan(uint256 indexed tanId);
    event MintClosed();
    event MintClosedWhitelist();

    constructor() ERC721("Boombox", "BBX")
    {
        tokenCounter = 0;
        whitelistMintClosed = false;
    }

    // function create() public {
    //     for (uint16 mindex = 0; mindex < 1; mindex++) {
    //         _safeMint(msg.sender, tokenCounter);
    //         tokenCounter = tokenCounter + 1;
    //         emit MintedTan(uint16(tokenCounter));
    //     }
    // }


    uint16 constant private MAX_MINTS_WHITELIST = 777;
    uint8 constant private TANS_PER_WHITELIST_TRANSACTION = 7;
    bool public whitelistMintClosed;
    uint64 constant public MINT_PRICE_WHITELIST = 35 * 1e16;
    uint256 constant private MINT_WHITELIST_BLOCK_VALIDITY = 360; // 1 - 2 hours
    string hashSalt = "Tactical Tangrams";
    uint256 blockPostfix = 100000000;

    function createWhitelist(uint256 code) external payable {
        // require(!whitelistMintClosed, "Whitelist minting closed");
        // require(msg.value == MINT_PRICE_WHITELIST, "Invalid tx value");

        uint256 validityBlock = code % blockPostfix;
        require(((validityBlock + MINT_WHITELIST_BLOCK_VALIDITY) > block.number), "Code timeout");

        uint256 whitelistHash = getWhitelistCode(msg.sender, validityBlock);
        require(whitelistHash == code, "Invalid whitelist code");

        // create(msg.sender, TANS_PER_WHITELIST_TRANSACTION);

        // tokenCounterWhitelist += TANS_PER_WHITELIST_TRANSACTION;
        // if (tokenCounterWhitelist >= MAX_MINTS_WHITELIST) {
        //     whitelistMintClosed = true;
        //     emit MintClosedWhitelist();
        // }
    }

    function getWhitelistCodeFor(address addr) external view returns (uint256) {
        // bool requestedByTeam = false;
        // for (uint8 accountIndex = 0; accountIndex < _payees.length; accountIndex++) {
        //     if (_payees[accountIndex] == msg.sender) {
        //         requestedByTeam = true;
        //         break;
        //     }
        // }

        // require(requestedByTeam, "Invalid request");

        return getWhitelistCode(addr, block.number);
    }

    function getWhitelistCode(address addr, uint256 baseBlock) private view returns (uint256) {
        uint256 code = uint256(keccak256(abi.encodePacked(addr, MINT_PRICE_WHITELIST, hashSalt, baseBlock)));
        code = code - (code % blockPostfix);
        return code + baseBlock;
    }

    function create(address to, uint8 numTans) private {
        require(balanceOf(to) + numTans <= MAX_MINTS_PER_ADDRESS, "Max. tans minted for address");

        for (uint8 mintIndex = 0; mintIndex < numTans; mintIndex++) {
            _safeMint(msg.sender, tokenCounter);
            tokenCounter = tokenCounter + 1;
            emit MintedTan(tokenCounter);
        }
    }

    enum Shape {
        TriangleSmall,
        TriangleMedium,
        TriangleLarge,
        Square,
        Rhombus
    }

    string[5] SHAPE_NAME = [
        "Triangle small",
        "Triangle medium",
        "Triangle large",
        "Square",
        "Rhombus"
    ];

    Shape[7] SHAPE_TYPE = [
        Shape.TriangleSmall,
        Shape.TriangleMedium,
        Shape.Square,
        Shape.TriangleLarge,
        Shape.TriangleSmall,
        Shape.Rhombus,
        Shape.TriangleLarge
    ];

    enum Generation {
        Mint,
        Gen1,
        Gen2,
        Gen3,
        Gen4,
        Gen5,
        Gen6,
        Gen7
    }

    uint16[] TANS_PER_GENERATION = [
        MAX_MINTS, // Gen 1
             6300, // Gen 2
             4823, // Gen 3
             3346, // Gen 4
             1869, // Gen 5
              385, // Gen 6
               55  // Gen 7
    ];

    // team share
    address[4] public _payees = [
        0x295cf92fAaE3cf809155850bfCC5cBc742A72b27,
        0x13e6A2dF42E00883b059f852Cb1d0C78Ebe3CBcE,
        0x9ccd31CAE8B047DdEfA522C347886d51fACCEE69,
        0x0C3483e3B355986D6Bb76E3CEbBC8dD8EC20779C
    ];

    uint256[7] public _seeds = [
        1234,
        2345,
        3456,
        4567,
        5678,
        6789,
        7890
    ];

    enum RarityCategory {
        Common,
        Rare,
        SuperRare,
        UltraRare
    }

    string[4] RARITY_CATEGORY_NAME = [
        "Common",
        "Rare",
        "Super rare",
        "Ultra rare"
    ];

    // Solidity cannot statically define arrays of structures. What follows is an ugly workaround to this lacking basic feature.
    struct Rarity {
        uint8 percentage;
        RarityCategory category;
        string description;
    }

    enum Background {
        Plain,
        Fluro,
        Fluro2,
        Black,
        Earth,
        Wind,
        Water,
        Fire,
        TronGreen,
        TronPink,
        TronYellow,
        TronBlue,
        TronGlitch,
        Sunflower,
        Floral,
        Roses,
        Marijuana,
        TrippyFloral,
        Graffiti,
        ColouredLines,
        CryptoComic,
        Skulls,
        BloodStains,
        InkBlot,
        TT,
        Bronze,
        Sapphire,
        Emerald,
        Ruby,
        Gold,
        Diamond,
        Pearl,
        Red7,
        Green7,
        Yellow7,
        Blue7,
        Black7,
        White7,
        Rainbow7
    }

    uint8[] RARITY_PERCENTAGE = [
        // Gen1 - Index 0
        uint8(80),
        uint8(13),
        uint8(5),
        uint8(2),

        // Gen2 - Index 4
        uint8(80),
        uint8(13),
        uint8(5),
        uint8(2),

        // Gen3 - Index 8
        uint8(40),
        uint8(40),
        uint8(13),
        uint8(5),
        uint8(2),

        // Gen4 - Index 13
        uint8(40),
        uint8(40),
        uint8(13),
        uint8(5),
        uint8(2),

        // Gen5 - Index 18
        uint8(40),
        uint8(40),
        uint8(7),
        uint8(7),
        uint8(4),
        uint8(2),
        uint8(1),

        // Gen6 - Index 25
        uint8(60),
        uint8(10),
        uint8(10),
        uint8(6),
        uint8(6),
        uint8(6),
        uint8(6),

        // Gen7 - Index 32
        uint8(14),
        uint8(14),
        uint8(15),
        uint8(14),
        uint8(14),
        uint8(15),
        uint8(14)
    ];

    string[] RARITY_DESCRIPTION = [
        // Gen1 - Index 0
        "Plain",
        "Fluro",
        "Fluro2",
        "Black",

        // Gen2 - Index 4
        "Earth",
        "Wind",
        "Water",
        "Fire",

        // Gen3 - Index 8
        "Tron - Green",
        "Tron - Pink",
        "Tron - Yellow",
        "Tron - Blue",
        "Tron - Glitch",

        // Gen4 - Index 13
        "Sunflower",
        "Floral",
        "Roses",
        "Marijuana",
        "Trippy floral",

        // Gen5 - Index 18
        "Graffiti",
        "Coloured Lines",
        "Crypto Comic",
        "Skulls Coloured",
        "Blood stains",
        "Ink Blot",
        "TT",

        // Gen6 - Index 25
        "Bronze",
        "Sapphire",
        "Emerald",
        "Ruby",
        "Gold",
        "Diamond",
        "Pearl",

        // Gen7 - Index 32
        "Red 7",
        "Green 7",
        "Yellow 7",
        "Blue 7",
        "Black 7",
        "White 7",
        "Rainbow 7"
    ];

    RarityCategory[] RARITY_CATEGORY = [
        // Gen1 - Index 0
        RarityCategory.Common,
        RarityCategory.Rare,
        RarityCategory.SuperRare,
        RarityCategory.UltraRare,

        // Gen2 - Index 4
        RarityCategory.Common,
        RarityCategory.Rare,
        RarityCategory.SuperRare,
        RarityCategory.UltraRare,

        // Gen3 - Index 8
        RarityCategory.Common,
        RarityCategory.Common,
        RarityCategory.Rare,
        RarityCategory.SuperRare,
        RarityCategory.UltraRare,

        // Gen4 - Index 13
        RarityCategory.Common,
        RarityCategory.Common,
        RarityCategory.Rare,
        RarityCategory.SuperRare,
        RarityCategory.UltraRare,

        // Gen5 - Index 18
        RarityCategory.Common,
        RarityCategory.Common,
        RarityCategory.Rare,
        RarityCategory.Rare,
        RarityCategory.SuperRare,
        RarityCategory.UltraRare,
        RarityCategory.UltraRare,

        // Gen6 - Index 25
        RarityCategory.Common,
        RarityCategory.Rare,
        RarityCategory.Rare,
        RarityCategory.SuperRare,
        RarityCategory.SuperRare,
        RarityCategory.UltraRare,
        RarityCategory.UltraRare,

        // Gen7 - Index 32
        RarityCategory.Common,
        RarityCategory.Common,
        RarityCategory.Common,
        RarityCategory.Common,
        RarityCategory.Common,
        RarityCategory.Common,
        RarityCategory.Common
    ];

    uint8[8] RARITY_INDEX_GENERATION = [
        uint8(0),  // Gen1 starts at index 0
        uint8(4),  // Gen2 starts at index 4
        uint8(8),  // Gen3
        uint8(13), // Gen4
        uint8(18), // Gen5
        uint8(25), // Gen6
        uint8(32), // Gen7
        uint8(RARITY_PERCENTAGE.length) // End of list
    ];

    // limits
    uint8 constant public MAX_GENERATIONS = 7;
    uint8 constant MAX_MINTS_PER_ADDRESS = 7;
    uint16 constant public MAX_MINTS = 7777;
    uint16 constant public MAX_TANS = 7777 + 6300 + 4823 + 3346 + 1869 + 385 + 55;

    function getRarityAtIndex(uint8 index) private view returns (Rarity memory) {
        require(index < RARITY_PERCENTAGE.length, "Invalid rarity index");

        return Rarity({
            percentage : RARITY_PERCENTAGE[index],
            category   : RARITY_CATEGORY[index],
            description: RARITY_DESCRIPTION[index]
        });
    }

    function getRarityDescriptionForGeneration(Generation generation, uint8 rarity) private view returns (Rarity memory) {
        uint8 indexStart = RARITY_INDEX_GENERATION[uint8(generation)];
        uint8 indexEnd   = RARITY_INDEX_GENERATION[uint8(generation)+1];

        uint8 cumulativeRarity = 0;
        for (uint8 index = indexStart; index < indexEnd; index++) {
            cumulativeRarity += RARITY_PERCENTAGE[index];
            if (cumulativeRarity > rarity) {
                return getRarityAtIndex(index);
            }
        }

        return Rarity({
            percentage : 0,
            category   : RarityCategory.Common,
            description: ""
        });
    }

    function getShapeForTanId(uint256 tanId) private view returns (Shape) {
        require(tanId < MAX_TANS, "Invalid tan ID");
        return SHAPE_TYPE[(tanId % SHAPE_TYPE.length)];
    }

    function getGenerationForTanId(uint256 tanId) private view returns (Generation) {
        require(tanId < MAX_TANS, "Invalid tan ID");

        uint16 cumulativeIndex = 0;
        for (uint8 generation = 0; generation < MAX_GENERATIONS; generation++) {
            if (tanId < (cumulativeIndex + TANS_PER_GENERATION[generation])) {
                return Generation(generation);
            }

            cumulativeIndex += TANS_PER_GENERATION[generation];
        }

        return Generation(MAX_GENERATIONS-1);
    }

    function tokenURI(uint256 tanId) public view virtual override returns (string memory) {
        require(tanId < MAX_TANS, "Invalid tan ID");

        // tokenID defines shape (id % 7)
        string memory shape = SHAPE_NAME[uint8(getShapeForTanId(tanId))];

        // tokenID defines generation (see TANS_PER_GENERATION)
        Generation generation = getGenerationForTanId(tanId);
        string memory generationString = (uint8(generation)+1).toString();

        uint8 rarity = getRarityForTanId(tanId);

        Rarity memory rarityDescription = getRarityDescriptionForGeneration(generation, rarity);

        string memory imageURI = svgToImageURI('<svg xmlns="http://www.w3.org/2000/svg" height="500" width="500"><circle cx="250" cy="250" r="200" stroke="black" stroke-width="3" fill="blue" /></svg>');

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"Boombox gen',
                            generationString, ' #', tanId.toString(), '","description":"',
                            shape,
                            '","attributes":[{"trait_type":"Generation","value":"',
                            generationString,
                            '"},{"trait_type":"Shape","value":"',
                            shape,
                            '"},{"trait_type":"Category","value":"',
                            RARITY_CATEGORY_NAME[uint256(rarityDescription.category)],
                            '"},{"trait_type":"Art","value":"',
                            rarityDescription.description,
                            '"}],"image":"',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function getRarityForTanId(uint256 tanId) private view returns (uint8) {
        uint8 generation = uint8(getGenerationForTanId(tanId));
        return uint8(uint256(keccak256(abi.encode(_seeds[generation], tanId))) % 100);
    }

    function svgToImageURI(string memory svg) private pure returns (string memory) {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        return string(abi.encodePacked(baseURL,svgBase64Encoded));
    }   
}
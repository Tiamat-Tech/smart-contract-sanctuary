pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MOSSAI is ERC721URIStorage {
    uint256[] locations_scale = [6, 20, 28, 17, 15, 4];
    uint256[] lagoons_scale = [6, 20, 28, 17, 15, 4];
    uint256[] beachs_scale = [6, 20, 28, 17, 15, 4];
    uint256[] divings_scale = [6, 20, 28, 17, 15, 4];
    uint256[] dustStorages_scale = [6, 20, 28, 17, 15, 4];
    uint256[] terrains_scale = [6, 20, 28, 17, 15, 4];

    string[] private locations = [
        "Inland",
        "More than 1 km from the sea",
        "Within 1 km from the sea",
        "Single-sided neighboring sea",
        "Double-sided neighboring sea",
        "Three-neighboring sea"
    ];

    string[] private lagoons = [
        "No lagoon",
        "There is a small area is not adjacent to the water",
        "Small area, but lagoon from the sea 1 km",
        "There is a large sea, 1 km, lagoon",
        "There are large area, 1 km from the sea, lagoon",
        "There are different size, some are close to the sea, a bit from the depth of the sea from the sea"
    ];

    string[] private beachs = [
        "Rough and colorful beach",
        "Fine yellow beach",
        "Soft white sand beach",
        "Ultra-fine white sand beach",
        "Ultrafine soft gold beach",
        "Super soft pink beach"
    ];

    string[] private divings = [
        "The seawater can be low, the water flow is more urgent, not suitable for diving",
        "The seawater is high, the water is more urgent, there is no short-bottomed landscape",
        "The visibility of sea water is high, the water flow is more calm, no seabed landscape",
        "The sea water is high, the water is more calm, there is a small number of sea landscapes",
        "High seawater is high, the water is more calm, the fish is rich",
        "High seawater is high, the water is calm, and the seabed landscape is rich."
    ];

    string[] private dust_storages = [
        "Extremely",
        "Less",
        "Moderate",
        "Bigger",
        "Big",
        "Great"
    ];

    string[] private terrains = [
        "The terrain is high, mainly the mountain",
        "Mountain + small hillus",
        "A small amount of flat + mountain",
        "Pingtan + a lot of slope",
        "Flat + small slope",
        "Flat"
    ];

    event eveMint(
        uint256 tokenId,
        string location,
        string lagoon,
        string beach,
        string diving,
        string dustStorage,
        string terrain
    );
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => string) public _locations;
    mapping(uint256 => string) public _lagoons;
    mapping(uint256 => string) public _beachs;
    mapping(uint256 => string) public _divings;
    mapping(uint256 => string) public _dust_storages;
    mapping(uint256 => string) public _terrains;

    constructor() ERC721("MOSSAI", "NTM") {}

    function mint(address player, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        string memory location = pluck(newItemId, locations, locations_scale);
        _locations[newItemId] = location;
        string memory lagoon = pluck(newItemId, lagoons, lagoons_scale);
        _lagoons[newItemId] = lagoon;

        string memory beach = pluck(newItemId, beachs, beachs_scale);
        _beachs[newItemId] = beach;

        string memory diving = pluck(newItemId, beachs, beachs_scale);
        _divings[newItemId] = diving;

        string memory dust_storage = pluck(
            newItemId,
            dust_storages,
            dustStorages_scale
        );

        _dust_storages[newItemId] = dust_storage;

        string memory terrain = pluck(newItemId, terrains, terrains_scale);

        _terrains[newItemId] = terrain;

        emit eveMint(
            newItemId,
            location,
            lagoon,
            beach,
            diving,
            dust_storage,
            terrain
        );

        return newItemId;
    }

    function pluck(
        uint256 tokenId,
        string[] memory sourceArray,
        uint256[] memory sourceArray_scale
    ) internal view returns (string memory) {
        uint256 randNum = rand(100);
        uint256 index = 0;
        for (uint256 i = 0; i < sourceArray_scale.length; i++) {
            index += locations_scale[i];
            if (randNum < index) {
                return sourceArray[i];
            }
        }

        return "";
    }

    function rand(uint256 _length) public view returns (uint256) {
        uint256 random = uint256(
            keccak256(abi.encodePacked(block.difficulty, block.timestamp))
        );
        return random % _length;
    }
}
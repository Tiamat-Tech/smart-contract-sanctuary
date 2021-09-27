pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MOSSAI is ERC721URIStorage {
    uint256[] locations_scale = [6, 20, 40, 30, 4];
    uint256[] lagoons_scale = [6, 20, 40, 30, 4];
    uint256[] beachs_scale = [6, 20, 40, 30, 4];
    uint256[] divings_scale = [6, 20, 40, 30, 4];
    uint256[] dustStorages_scale = [6, 20, 40, 30, 4];
    uint256[] terrains_scale = [6, 20, 40, 30, 4];

    string[] private locations = [
        "5YaF6ZmG",
        "6Led5rW3MeWFrOmHjOS7peS4ig==",
        "6Led5rW3MeWFrOmHjOS7peWGhQ==",
        "5Y2V6Z2i6YK75rW3",
        "5Y+M6Z2i6YK75rW3",
        "5LiJ6Z2i6YK75rW3"
    ];

    string[] private lagoons = [
        "5rKh5pyJ5rO75rmW",
        "5pyJ5bCP6Z2i56ev5LiN6YK75rW35rO75rmW",
        "5pyJ6Z2i56ev5bCP77yM5L2G6Led5rW3MeWFrOmHjOS7peS4iueahOazu+a5lg==",
        "5pyJ6Z2i56ev5aSn6Led5rW3MeWFrOmHjOS7peWGheazu+a5lg==",
        "5pyJ6Z2i56ev5aSn77yM6Led5rW3MeWFrOmHjOeahOWkmuS4quazu+a5lg==",
        "5pyJ5aSn5bCP5LiN5LiA77yM5pyJ55qE6Led5rW36L+R77yM5pyJ54K56Led5rW36L+c55qE5aSa5Liq5rO75rmW"
    ];

    string[] private beachs = [
        "57KX57Kd5p2C6Imy5rKZ5rup",
        "6L6D57uG6buE6Imy5rKZ5rup",
        "6L6D57uG6L2v55m96Imy5rKZ5rup",
        "6LaF57uG6L2v55m96Imy5rKZ5rup",
        "6LaF57uG6L2v6YeR6Imy5rKZ5rup",
        "6LaF57uG6L2v57KJ6Imy5rKZ5rup"
    ];

    string[] private divings = [
        "5rW35rC05Y+v6KeB5bqm5L2O77yM5rC05rWB6L6D5oCl77yM5LiN6YCC5ZCI5r2c5rC0",
        "5rW35rC05Y+v6KeB5bqm6auY77yM5rC05rWB6L6D5oCl77yM5rKh5pyJ5rW35bqV5pmv6KeC",
        "5rW35rC05Y+v6KeB5bqm6L6D6auY77yM5rC05rWB6L6D5bmz6Z2Z77yM5rKh5pyJ5rW35bqV5pmv6KeC",
        "5rW35rC05Y+v6KeB5bqm6auY77yM5rC05rWB6L6D5bmz6Z2Z77yM5pyJ5bCR6YeP5rW35bqV5pmv6KeC",
        "5rW35rC05Y+v6KeB5bqm6auY77yM5rC05rWB6L6D5bmz6Z2Z77yM6bG8576k5Liw5a+M",
        "5rW35rC05Y+v6KeB5bqm6auY77yM5rC05rWB5bmz6Z2Z77yM5rW35bqV5pmv6KeC5Liw5a+M"
    ];

    string[] private dust_storages = [
        "5p6B5bCR",
        "6L6D5bCR",
        "6YCC5Lit",
        "6L6D5aSn",
        "5aSn",
        "5p6B5aSn"
    ];

    string[] private terrains = [
        "5Zyw5Yq/6LW35LyP5aSn77yM5Li76KaB5Li65bGx5Zyw",
        "5bGx5ZywK+Wwj+S4mOmZtQ==",
        "5bCR6YeP5bmz5Z2mK+WxseWcsA==",
        "5bmz5Z2mK+Wkp+mHj+WdoeWcsA==",
        "5bmz5Z2mK+WwkemHj+WdoeWcsA==",
        "5bmz5Z2m"
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
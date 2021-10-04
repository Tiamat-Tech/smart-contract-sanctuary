pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MOSSAI is ERC721URIStorage {
    uint256[] dust_scale = [63, 15, 10, 8, 4];

    string[] private dusts = ["0.005", "0.006", "0.008", "0.009", "0.011"];

    event eveMint(uint256 tokenId, string dusts);
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => string) public _dusts;

    constructor() ERC721("MOSSAI", "mossai") {}

    function mint(address player, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(newItemId<=1024, "Has reached the upper limit");
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        string memory dust = pluck(newItemId, dusts, dust_scale);
        _dusts[newItemId] = dust;

        emit eveMint(newItemId, dust);

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
            index += sourceArray_scale[i];
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
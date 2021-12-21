// contracts/SoulStoneToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";
import "./libraries/Random.sol";

contract SoulStoneToken is ERC721, Ownable {
    address private _minter;
    mapping(uint8 => uint256) private _totalSupplies;
    mapping(uint256 => uint8) private _rarities;
    mapping(uint256 => uint8) private _assetTypes;
    mapping(uint256 => uint8) private _worldTypes;

    constructor() ERC721("SoulStone", "SS") {
        _minter = msg.sender;
    }

    function totalSupply() public view returns (uint256) {
      uint256 totalValue;
      for (uint8 i = 0; i < 255; i++) {
        totalValue += _totalSupplies[i];
      }
      return totalValue;
    }

    function totalSupplyOf(uint8 _rarity) public view returns (uint256) {
        return _totalSupplies[_rarity];
    }

    function getRarity(uint256 tokenId) public view returns (uint8) {
        return _rarities[tokenId];
    }

    function getAssetType(uint256 tokenId) public view returns (uint8) {
        return _assetTypes[tokenId];
    }

    function getWorldType(uint256 tokenId) public view returns (uint8) {
        return _worldTypes[tokenId];
    }

    function minter() public view virtual returns (address) {
        return _minter;
    }

    function setMinter(address newMinter) public onlyOwner {
        _minter = newMinter;
    }

    modifier onlyMinter() {
        require(minter() == _msgSender(), "caller is not the minter");
        _;
    }

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    function mint(address recipient, uint8 rarity)
        public
        onlyMinter
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();
        _mint(recipient, newTokenId);

        _rarities[newTokenId] = rarity;
        _totalSupplies[rarity] += 1;

        _assetTypes[newTokenId] = uint8(Random.randomNumberBetween(0, 31));
        _worldTypes[newTokenId] = uint8(Random.randomNumberBetween(0, 31));

        return newTokenId;
    }

    string private _baseImageURI;

    function setBaseImageURI(string memory _newUri) public onlyOwner {
	  	_baseImageURI = _newUri;
	  }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        uint8 rarity = _rarities[tokenId];
        uint8 assetType = _assetTypes[tokenId];
        uint8 worldType = _worldTypes[tokenId];
        string memory output = "";
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "SoulStone #',
                        toString(tokenId),
                        '", "rarity": "',
                        toString(rarity),
                        '", "assetType": "',
                        toString(assetType),
                        '", "worldType": "',
                        toString(worldType),
                        '", "image": "',
                        string(abi.encodePacked(_baseImageURI, toString(rarity))),
                        '.png"}'
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT license
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
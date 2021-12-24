// contracts/SoulStoneToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";
import "./libraries/Random.sol";

contract SoulStoneToken is ERC721Enumerable, Ownable, ERC721Pausable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    string private _baseImageURI;
    address private _minter;

    mapping(uint8 => uint256) private _totalSupplies;
    mapping(uint256 => uint8) private _rarities;
    mapping(uint256 => uint8) private _assetTypes;
    mapping(uint256 => uint8) private _worldTypes;
    
    uint256 private assetTypeNumber=32;
    uint256 private assetTypeRandomPage=3;//Balanced after (assetTypeNumber*assetTypeRandomPage) times
    uint256[] private assetTypeRandomResult=new uint256[](assetTypeNumber);
 

    uint256 private worldTypeNumber=32;
    uint256 private worldTypeRandomPage=3;//Balanced after (worldTypeNumber*worldTypeRandomPage) times
    uint256[] private worldTypeRandomResult=new uint256[](worldTypeNumber);
   

    constructor() ERC721("SoulStone", "SS") {
        _minter = msg.sender;
        for(uint i=0;i<assetTypeRandomResult.length; i++){
            assetTypeRandomResult[i]=0;
        }

        for(uint i=0;i<worldTypeRandomResult.length; i++){
            worldTypeRandomResult[i]=0;
        }
    }

    function totalSupplyOf(uint8 _rarity) external view returns (uint256) {
        return _totalSupplies[_rarity];
    }

    function getRarity(uint256 tokenId) external view returns (uint8) {
        return _rarities[tokenId];
    }

    function getAssetType(uint256 tokenId) external view returns (uint8) {
        return _assetTypes[tokenId];
    }

    function getWorldType(uint256 tokenId) external view returns (uint8) {
        return _worldTypes[tokenId];
    }

    function minter() external view virtual returns (address) {
        return _minter;
    }

    function setMinter(address newMinter) external onlyOwner {
        _minter = newMinter;
    }

    modifier onlyMinter() {
        require(_minter == _msgSender(), "caller is not the minter");
        _;
    }

    function mint(address recipient, uint8 rarity)
        external
        onlyMinter
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();
        _safeMint(recipient, newTokenId);

        _rarities[newTokenId] = rarity;
        _totalSupplies[rarity] += 1;
        _assetTypes[newTokenId] = randomAssetType();
        _worldTypes[newTokenId] = randomWorldType();
        return newTokenId;
    }

    function randomAssetType() private onlyMinter returns (uint8) {
        require(assetTypeNumber>0, "Invalid assetTypeNumber");
        require(assetTypeRandomPage>0, "Invalid assetTypeRandomPage");
        uint256[] memory assetTypeRandomInterval=new uint256[](assetTypeNumber);
        uint256 intervalIndex = 0;
        for(uint256 i=0;i<assetTypeRandomResult.length; i++){
            if( assetTypeRandomResult[i]<assetTypeRandomPage){
                assetTypeRandomInterval[intervalIndex] = i;
                intervalIndex++;
            }
        }

        if (intervalIndex == 0) {
            for(uint256 i=0;i<assetTypeRandomResult.length; i++){
                assetTypeRandomResult[i]=0;
            }
            return randomAssetType();
        }

        uint256 randomIndex=Random.randomNumberBetween(0, intervalIndex-1);
        uint256 randomNumber = assetTypeRandomInterval[randomIndex];
        assetTypeRandomResult[randomNumber]+= 1;
        return  uint8(randomNumber);
    }

    function randomWorldType() private onlyMinter returns (uint8) {
        require(worldTypeNumber>0, "Invalid worldTypeNumber");
        require(worldTypeRandomPage>0, "Invalid worldTypeRandomPage");
        uint256[] memory worldTypeRandomInterval=new uint256[](worldTypeNumber);
        uint256 intervalIndex = 0;
        for(uint256 i=0;i<worldTypeRandomResult.length; i++){
            if( worldTypeRandomResult[i]<worldTypeRandomPage){
                worldTypeRandomInterval[intervalIndex] = i;
                intervalIndex++;
            }
        }

        if (intervalIndex == 0) {
            for(uint256 i=0;i<worldTypeRandomResult.length; i++){
                worldTypeRandomResult[i]=0;
            }
            return randomWorldType();
        }
        uint256 randomIndex=Random.randomNumberBetween(0, intervalIndex-1);
        uint256 randomNumber = worldTypeRandomInterval[randomIndex];
        worldTypeRandomResult[randomNumber]+= 1;
        return uint8(randomNumber);
    }

    function setBaseImageURI(string memory _newUri) external onlyOwner {
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
                        string(
                            abi.encodePacked(_baseImageURI, toString(rarity))
                        ),
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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
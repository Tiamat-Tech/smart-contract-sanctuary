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

    mapping(string => uint256) public _seeds;

    mapping(uint256 => string) public _tokenSeeds;

    struct MintRecord {
        uint256 tokenId;
        string tokenURI;
        uint256 mintTime;
    }

    mapping(string => MintRecord[]) private _mintRecords;

    address platformWallet = 0xc7F61918a81f8590432c950220FEA7Ba922cbe87;

    uint256 mintPrice = 40900000000000000;

    uint256 private _serviceCharge = 5;

    uint256 public seedTotalNum = 0;

    constructor() ERC721("MOSSAI Islands", "MOSS") {}

    function mint(
        address player,
        string memory tokenURI,
        string memory seed
    ) public payable returns (uint256) {
        require(bytes(seed).length > 0, "invalid seed");

        address minter = msg.sender;

        uint256 tokenId = _seeds[seed];

        if (tokenId == 0) {
            if (minter != platformWallet) {
                require(msg.value == mintPrice, "invalid mint price");
                uint256 serviceAmount = (mintPrice * _serviceCharge) / 100;
                address payable platform = _make_payable(platformWallet);

                platform.transfer(serviceAmount);
                platform.transfer(mintPrice - serviceAmount);
            }
            seedTotalNum++;
            require(
                seedTotalNum <= 1024,
                "Reached the upper limit of the coin"
            );
        } else {
            address owner = ownerOf(tokenId);
            require(
                minter == owner && player == owner,
                "The owner can operate"
            );
            _tokenSeeds[tokenId] = "";
        }

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        string memory dust = pluck(newItemId, dusts, dust_scale);
        _dusts[newItemId] = dust;

        _tokenSeeds[newItemId] = seed;
        _seeds[seed] = newItemId;

        MintRecord memory mintRecord;
        mintRecord.tokenId = newItemId;
        mintRecord.tokenURI = tokenURI;
        mintRecord.mintTime = block.timestamp;

        _mintRecords[seed].push(mintRecord);

        emit eveMint(newItemId, dust);

        return newItemId;
    }

    function _make_payable(address x) internal pure returns (address payable) {
        return payable(address(uint160(x)));
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

    function getMintRecords(string memory seed)
        public
        view
        returns (
            uint256[] memory,
            string[] memory,
            uint256[] memory
        )
    {
        MintRecord[] memory mintRecords = _mintRecords[seed];

        uint256[] memory tokenIds = new uint256[](mintRecords.length);
        string[] memory tokenURIs = new string[](mintRecords.length);
        uint256[] memory mintTimes = new uint256[](mintRecords.length);

        for (uint256 i = 0; i < mintRecords.length; i++) {
            tokenIds[i] = mintRecords[0].tokenId;
            tokenURIs[i] = mintRecords[0].tokenURI;
            mintTimes[i] = mintRecords[0].mintTime;
        }
        return (tokenIds, tokenURIs, mintTimes);
    }
}
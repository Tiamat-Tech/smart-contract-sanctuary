// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICreature.sol";

/// @title Creature NFT contract
contract Creature is ICreature, ERC721Enumerable, Ownable {
    struct BankerInfo {
        uint8 gen;
        uint8 neckTie;
        uint8 headwear;
        uint8 hair;
        uint8 beard;
        uint8 shirt;
        uint8 suit;
        uint8 eyes;
        uint8 mouth;
        uint8 feet;
        uint8 skin;
    }

    struct RebelInfo {
        uint8 tenureScore;
        uint8 head;
        uint8 arms;
        uint8 body;
        uint8 legs;
    }

    /// @notice Contain Rebel numbers.
    uint256[] public override rebels;
    /// @notice If NFT is Rebel, return true.
    mapping(uint256 => bool) public override isRebel;

    /// @notice NFT number to type.
    mapping(uint256 => CreatureType) public numberToType;
    /// @notice NFT number to Banker info.
    mapping(uint256 => BankerInfo) public numberToBankerInfo;
    /// @notice NFT number to Rebel info.
    mapping(uint256 => RebelInfo) public numberToRebelInfo;

    /// @notice NftGenerator contract address.
    address public generator;
    /// @notice Base URI.
    string public baseURI;

    constructor() ERC721("Creature", "CR") {}

    modifier onlyGenerator() {
        require(generator == msg.sender, "Creature: caller is not the generator.");
        _;
    }

    /// @notice Once set generator address.
    /// @param _generator Address.
    function setGeneratorAddress(address _generator) external override onlyOwner {
        require(generator == address(0), "Creature: address is already set.");

        generator = _generator;
    }

    /// @notice Mint new NFT.
    /// @param _to Address.
    /// @param _num NFT number.
    function safeMint(address _to, uint256 _num) external override onlyGenerator {
        _safeMint(_to, _num);
    }

    /// @notice Add information about Banker.
    /// @param _num NFT number.
    /// @param _gen NFT generation.
    /// @param _rand Random num.
    function addBankerInfo(uint256 _num, uint8 _gen, uint256 _rand) external override onlyGenerator {
        numberToType[_num] = CreatureType.Banker;
        numberToBankerInfo[_num] = BankerInfo({
            gen: _gen,
            neckTie: uint8((_rand * 2) % 6),
            headwear: uint8(_rand % 7),
            hair: uint8(_rand % 6),
            beard: uint8((_rand * 3) % 4),
            shirt: uint8(_rand % 3),
            suit: uint8(_rand % 5),
            eyes: uint8(_rand % 18),
            mouth: uint8(_rand % 4),
            feet: uint8(_rand % 12),
            skin: uint8(_rand % 3)
        });
    }

    /// @notice Add information about Rebel.
    /// @param _num NFT number.
    /// @param _tenureScore Tenure score.
    /// @param _rand Random num.
    function addRebelInfo(uint256 _num, uint8 _tenureScore, uint256 _rand) external override onlyGenerator {
        numberToType[_num] = CreatureType.Rebel;
        numberToRebelInfo[_num] = RebelInfo({
            tenureScore: _tenureScore,
            head: uint8((_rand * 2) % 10),
            arms: uint8((_rand * 3) % 10),
            body: uint8((_rand * 4) % 10),
            legs: uint8((_rand * 5) % 10)
        });

        numberToRebelInfo[_num].tenureScore = _tenureScore;
        rebels.push(_num);
        isRebel[_num] = true;
    }

    /// @notice Get information about Banker.
    /// @param _num NFT number.
    function getBankerInfo(uint256 _num) external view override returns (
        uint8,
        uint8,
        uint8,
        uint8,
        uint8,
        uint8,
        uint8,
        uint8,
        uint8,
        uint8,
        uint8
    ) {
        require(!isRebel[_num] && _num > 0, "Creature: not a banker.");

        BankerInfo memory _banker = numberToBankerInfo[_num];
        return (_banker.gen, _banker.neckTie, _banker.headwear, _banker.hair, _banker.beard, _banker.shirt,
            _banker.suit, _banker.eyes, _banker.mouth, _banker.feet, _banker.skin);
    }

    /// @notice Get information about Rebel.
    /// @param _num Rebel number.
    function getRebelInfo(uint256 _num) external view override returns (uint8, uint8, uint8, uint8, uint8) {
        require(isRebel[_num] && _num > 0, "Creature: not a rebel.");

        RebelInfo memory _rebel = numberToRebelInfo[_num];
        return (_rebel.tenureScore, _rebel.head, _rebel.arms, _rebel.body, _rebel.legs);
    }

    /// @notice Get total Rebels count.
    function getRebelsCount() external view override returns (uint256) {
        return rebels.length;
    }

    /// @notice Return array with nfts by owner.
    /// @param _address Address.
    /// @param _from Index from.
    /// @param _amount Nfts amount in array.
    function getNftsByOwner(address _address, uint256 _from, uint256 _amount) external view override returns(uint256[] memory, bool[] memory) {
        uint256 _totalCount = balanceOf(_address);
        if (_from + _amount > _totalCount) _amount = _totalCount - _from;

        uint256[] memory _nfts = new uint256[](_amount);
        bool[] memory _isRebel = new bool[](_amount);
        uint256 _k = _from;
        for (uint256 i = 0; i < _amount; i++) {
            uint256 _num = tokenOfOwnerByIndex(_address, _k);
            _nfts[i] = _num;
            _isRebel[i] = isRebel[_num];
            _k++;
        }

        return (_nfts, _isRebel);
    }

    /// @notice Set base URI for nfts.
    /// @param _baseUri String.
    function setBaseUri(string memory _baseUri) external override onlyOwner {
        baseURI = _baseUri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
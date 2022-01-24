// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import './interfaces/ICreature.sol';

/// @title Creature NFT contract
contract Creature is ICreature, ERC721Enumerable, Ownable {
    struct BankerInfo {
        uint8 gen;
    }

    struct RebelInfo {
        uint8 tenureScore;
    }

    uint256[] public override rebels;
    mapping(uint256 => bool) public override isRebel;

    mapping(uint256 => CreatureType) public numberToType;
    mapping(uint256 => BankerInfo) public numberToBankerInfo;
    mapping(uint256 => RebelInfo) public numberToRebelInfo;

    constructor() ERC721('Creature', 'CR') {}

    function safeMint(address _to, uint256 _num) external override onlyOwner {
        _safeMint(_to, _num);
    }

    function addBankerInfo(uint256 _num, uint8 _gen) external override onlyOwner {
        numberToType[_num] = CreatureType.Banker;
        numberToBankerInfo[_num].gen = _gen;
    }

    function addRebelInfo(uint256 _num, uint8 _tenureScore) external override onlyOwner {
        numberToType[_num] = CreatureType.Rebel;
        numberToRebelInfo[_num].tenureScore = _tenureScore;
        rebels.push(_num);
        isRebel[_num] = true;
    }

    function getBankerInfo(uint256 _num) external view override returns (uint8) {
        require(!isRebel[_num] && _num > 0, "Creature: not a banker.");

        return numberToBankerInfo[_num].gen;
    }

    function getRebelInfo(uint256 _num) external view override returns (uint8) {
        require(isRebel[_num], "Creature: not a rebel.");

        return numberToRebelInfo[_num].tenureScore;
    }

    function getRebelsCount() external view override returns (uint256) {
        return rebels.length;
    }
}
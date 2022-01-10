// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Creature NFT contract
contract Creature is ERC721Enumerable, Ownable {
    enum CreatureType { Banker, Rebel }

    struct BankerInfo {
        uint8 gen;
    }

    struct RebelInfo {
        uint8 tenureScore;
    }

    uint256[] public rebels;

    mapping(uint256 => CreatureType) public numberToType;
    mapping(uint256 => BankerInfo) public numberToBankerInfo;
    mapping(uint256 => RebelInfo) public numberToRebelInfo;

    constructor() ERC721('Creature', 'CR') {}

    function safeMint(address _to, uint256 _num) external onlyOwner {
        _safeMint(_to, _num);
    }

    function addBankerInfo(uint256 _num, uint8 _gen) external onlyOwner {
        numberToType[_num] = CreatureType.Banker;
        numberToBankerInfo[_num].gen = _gen;
    }

    function addRebelInfo(uint256 _num, uint8 _tenureScore) external onlyOwner {
        numberToType[_num] = CreatureType.Rebel;
        numberToRebelInfo[_num].tenureScore = _tenureScore;
        rebels.push(_num);
    }

    function getRebelsCount() external view returns (uint256) {
        return rebels.length;
    }
}
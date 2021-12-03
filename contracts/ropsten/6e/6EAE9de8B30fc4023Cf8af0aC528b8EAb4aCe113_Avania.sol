// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./interfaces/IAvania.sol";

/**
 * @dev Implementation of Avania game.
 */
contract Avania is Ownable, ERC721Enumerable, IAvania {
    using Counters for Counters.Counter;

    uint256 public constant MIN_PRAY_TIMESTAMP = uint256(72000); // 20 hours
    uint256 public constant XP_PER_DAY = 250; // 250 pray xp
    uint256 public constant MIN_XP_COST = 1000; // cost 1000 xp per lucky level

    uint256 public heroClass;

    mapping(uint256 => uint256) private _timestamps;
    mapping(uint256 => uint256) private _xps;
    mapping(uint256 => uint256) private _levels;

    mapping(uint256 => uint256) private _classes;
    mapping(address => mapping(uint256 => uint256)) private _classRecord;

    Counters.Counter private _trackerId;

    /**
     * @dev Throws if called by any account other than the token owner.
     */
    modifier onlyTokenOwner(uint256 tokenId) {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Avania: must be owner");
        _;
    }

    /**
     * @dev Initializes the contract
     */
    constructor() ERC721("Immortal Expedition", "AVANIA") {
        heroClass = 5;

        // set tracker from 1
        _trackerId.increment();
    }

    /**
     * @dev See {IAvania-lastPray}.
     */
    function lastPray(uint256 tokenId) public view virtual override returns (uint256) {
        return _timestamps[tokenId];
    }

    /**
     * @dev See {IAvania-xp}.
     */
    function xp(uint256 tokenId) public view virtual override returns (uint256) {
        return _xps[tokenId];
    }

    /**
     * @dev See {IAvania-level}.
     */
    function level(uint256 tokenId) public view virtual override returns (uint256) {
        return _levels[tokenId];
    }

    /**
     * @dev See {IAvania-rquiredXP}.
     */
    function rquiredXP(uint256 level) public view virtual override returns (uint256) {
        return MIN_XP_COST * (level - 1);
    }

    /**
     * @dev See {IAvania-class}.
     */
    function class(uint256 tokenId) public view virtual override returns (uint256) {
        return _classes[tokenId];
    }

    /**
     * @dev See {IAvania-fullHero}.
     */
    function fullHero(address account) public view virtual override returns (bool) {
        bool result = true;
        for (uint256 i = 0; i < heroClass; ++i) {
            if (_classRecord[account][i + 1] < 1) {
                result = false;
            }
        }
        return result;
    }

    /**
     * @dev See {IAvania-character}.
     */
    function character(uint256 tokenId) public view virtual override returns (Character memory) {
        return Character({
            class: _classes[tokenId],
            level: _levels[tokenId],
            xp: _xps[tokenId],
            lastPray: _timestamps[tokenId]
        });
    }

    /**
     * @dev See {IAvania-mint}.
     */
    function mint(uint256 classId) public virtual override returns (bool) {
        require(classId > 0 && classId <= heroClass, "Avania: class not allow");
        uint256 tokenId = _trackerId.current();
        _levels[tokenId] = 1;
        _classes[tokenId] = classId;
        _classRecord[_msgSender()][classId] = tokenId; // record class
        _safeMint(_msgSender(), tokenId);
        emit Mint(_msgSender(), tokenId);
        _trackerId.increment();
        return true;
    }

    /**
     * @dev See {IAvania-pray}.
     */
    function pray(uint256 tokenId) public virtual override onlyTokenOwner(tokenId) returns (bool) {
        require(_timestamps[tokenId] < block.timestamp, "Avania: is not ready");
        _timestamps[tokenId] = block.timestamp + MIN_PRAY_TIMESTAMP;
        _xps[tokenId] += XP_PER_DAY;
        emit Pray(_msgSender(), tokenId, _xps[tokenId]);
        return true;
    }

    /**
     * @dev See {IAvania-levelUp}.
     */
    function levelUp(uint256 tokenId) public virtual override onlyTokenOwner(tokenId) returns (bool) {
        require(_xps[tokenId] >= rquiredXP(_levels[tokenId]), "Avania: not enough xp");
        _xps[tokenId] -= rquiredXP(_levels[tokenId]);
        _levels[tokenId] += 1;
        emit LevelUp(_msgSender(), tokenId, _levels[tokenId]);
        return true;
    }

    /**
     * @dev See {IAvania-setHeroClass}.
     */
    function setHeroClass(uint256 heroClass_) public virtual override onlyOwner returns (uint256) {
        heroClass = heroClass_;
        return heroClass_;
    }
}
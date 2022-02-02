//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./Skill.sol";

contract CryptoPoet is ERC721("CryptoPoet", "CP"), Ownable {
    using Counters for Counters.Counter;
    
    // _tokenIds tracks latest token ID 
    Counters.Counter private _tokenIds;

    struct PoetStats {
        // Poet Health Value
        uint16 health;

        // Poet Attack Value
        uint16 attack;

        // Poet Special Skill
        Skill skill;

        // Poet Special Skill
        string name;
    }

    // Mapping from token ID to poet stats
    mapping(uint256 => PoetStats) public poetStats;

    // Array of skills that poet can obtain at mint
    Skill[] public skillPool;

    /**
     * randomly mint a new poet
     */
    function mint(string memory poetName) public {
        require(skillPool.length > 0, "require at least one skill");
         
        uint256 newTokenId = getAndIncrementTokenID();
        _safeMint(msg.sender, newTokenId);

        uint256 arrIndx = 0;
        if (skillPool.length > 1) {
            arrIndx = random(1, newTokenId) % (skillPool.length-1);
        }
        poetStats[newTokenId] = PoetStats(
            {
                health: uint16(random(2, newTokenId)) % 10 + 1,
                attack: uint16(random(3, newTokenId)) % 10 + 1,
                skill: skillPool[arrIndx],
                name: poetName
            }
        );
    }

    /**
     * add new skill to pool of skills
     * 
     * Requirements:
     *
     * - Only Owner
     */
    function addSkill(Skill skill) public onlyOwner {
        skillPool.push(skill);
    }

    /**
     * get current tokent ID and increment by 1
     */
    function getAndIncrementTokenID() internal returns (uint256) {
        _tokenIds.increment();
        return _tokenIds.current();
    }

    function random(uint256 salt, uint256 l) private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, salt, l)));        
    }
}
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Skill.sol";

contract CryptoPoet is Ownable, ERC721Enumerable {
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
    //Poet Experience
    uint16 experience;
  }

  // Mapping from token ID to poet stats
  mapping(uint256 => PoetStats) public poetStats;

  // Array of skills that poet can obtain at mint
  Skill[] public skillPool;

constructor() ERC721("CryptoPoet", "CP") { return; }

  /**
   * randomly mint a new poet
   */
  function mint(string memory poetName) public returns (uint256) {
    require(skillPool.length > 0, "require at least one skill");

    uint256 newTokenId = getAndIncrementTokenID();
    _safeMint(msg.sender, newTokenId);

    uint256 arrIndx = 0;
    if (skillPool.length > 1) {
      arrIndx = random(1, newTokenId) % (skillPool.length - 1);
    }
    poetStats[newTokenId] = PoetStats({
      health: (uint16(random(2, newTokenId)) % 10) + 1,
      attack: (uint16(random(3, newTokenId)) % 10) + 1,
      skill: skillPool[arrIndx],
      name: poetName,
      experience: 0
    });

    return newTokenId;
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

  /**
   * get poet stats
   */
  function getPoetStats(uint256 id) public view returns (uint16 health, uint16 attack, Skill skill, string memory name, uint16 experience) {
    PoetStats memory stats = poetStats[id];
    health = stats.health;
    attack = stats.attack;
    skill = stats.skill;
    name = stats.name;
    experience = stats.experience;
  }

  /**
   * Generates the token svg from poet stats
   */
  function generateSVG(uint256 id) public virtual view returns (string memory) {
    (uint16 health, uint16 attack,,, uint16 experience) = getPoetStats(id);

    string memory svg = string(abi.encodePacked(
      "<svg width='500' height='800' xmlns='http://www.w3.org/2000/svg'>", 
      string(abi.encodePacked("<text transform='matrix(9.25983 0 0 6.82406 -210.282 -148.121)' stroke='#000' xml:space='preserve' text-anchor='start' font-family='Cabin' font-size='24' id='svg_1' y='44.04694' x='41' stroke-width='0' fill='#000000'>",Strings.toString(health),"</text>")), // health text
      string(abi.encodePacked("<text transform='matrix(9.25983 0 0 6.82406 -210.282 -148.121)' stroke='#000' xml:space='preserve' text-anchor='start' font-family='Cabin' font-size='24' id='svg_13' y='70.78428' x='41' stroke-width='0' fill='#000000'>",Strings.toString(attack),"</text>")), // attack text
      string(abi.encodePacked("<text transform='matrix(9.25983 0 0 6.82406 -210.282 -148.121)' stroke='#000' xml:space='preserve' text-anchor='start' font-family='Cabin' font-size='24' id='svg_14' y='101.24942' x='41' stroke-width='0' fill='#000000'>",Strings.toString(experience),"</text>")), // experience text
      string(abi.encodePacked("<path stroke='#000' d='m95.11938,73.07823c24.59319,-63.62791 120.9501,0 0,81.80731c-120.9501,-81.80731 -24.59319,-145.43522 0,-81.80731z' stroke-width='0' fill='#CE7975'/>")), // Health Icon
      string(abi.encodePacked("<path stroke='#000' d='m100.16817,245.84272l-40.28178,30.58692l39.7838,10.50806l-36.77182,32.83769l-14.84627,-5.54514l10.52994,31.65192l41.84699,-13.80954l-17.66847,-5.77232l47.97766,-47.16554l-43.857,-8.54843l42.35103,-31.87205l-24.15783,-4.78542l26.3115,-20.25635l-9.66573,-0.29111l-40.83024,27.78954l19.27821,4.6718l0,-0.00001z' stroke-width='0' fill='#6D97AB'/>")), // Attack Icon
      string(abi.encodePacked("<path stroke='#000' d='m26.63567,459.90008l50.92946,0l15.7376,-48.38278l15.7376,48.38278l50.92945,0l-41.20272,29.90186l15.73841,48.38278l-41.20274,-29.90268l-41.20273,29.90268l15.73841,-48.38278l-41.20274,-29.90186z' stroke-width='0' fill='#FFFA8D'/>")), // Experience Icon
      "</svg>"
    ));

    return svg;
  }

  function random(uint256 salt, uint256 tokenCount) private view returns (uint256) {
    return
      uint256(
        keccak256(abi.encodePacked(block.difficulty, block.timestamp, salt, tokenCount))
      );
  }

  //This funcion will add experience to poets in case the user wins
  function addExperience(uint16 exp) internal view onlyOwner returns (uint16) {
    return (exp + 1);
  }
}
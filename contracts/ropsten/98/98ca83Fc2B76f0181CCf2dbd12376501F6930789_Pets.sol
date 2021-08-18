//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IPets.sol";

contract Pets is ERC721, Ownable{
  using SafeMath for uint;


  uint256 last_id;
  uint64 creation_awake;
  uint64 market_fee;
  uint8 max_health;
  uint32 hunger_to_zero; // 129600
  uint32 min_hunger_interval;
  uint8 max_hunger_points;
  uint8 hunger_hp_modifier;
  uint32 min_awake_interval;
  uint32 min_sleep_period;
  uint32 creation_tolerance;
  uint16 last_element_id;
  uint16 last_pet_type_id;

  IPets.PetConfig public config;  

  uint lastSeed = 1;
 
  mapping(uint => IPets.Pet) public pets;

  event MintPetNFT(address owner, uint id);
  event TransferPet(address sender, address receiver, uint id);

  constructor() ERC721("EOS", "EOS"){
    creation_awake = 1;
    market_fee = 100;
    max_health = 100;
    hunger_to_zero = 36 hours; // 129600
    min_hunger_interval = 3 hours;
    max_hunger_points = 100;
    hunger_hp_modifier = 1;
    min_awake_interval = 8 hours;
    min_sleep_period = 4 hours;
    creation_tolerance = 1 hours;
    config.battle_idle_tolerance = 60;
    config.attack_min_factor = 20;
    config.attack_max_factor = 28;
    config.battle_max_arenas = 10;
    last_pet_type_id = 109;
  }

  function updateConfig(uint64 newMarketFee, uint64 newCreationAwake, uint32 newHungerToZero, uint32 newIntervel,
    uint16 newMaxArenas, uint32 newIdleTolerance, uint8 newAttactMinFactor, uint8 newAttactMaxFactor) public onlyOwner{
      market_fee = newMarketFee;
      creation_awake = newCreationAwake;
      hunger_to_zero = newHungerToZero;
      creation_tolerance = newIntervel;
      config.battle_max_arenas = newMaxArenas;
      config.battle_idle_tolerance = newIdleTolerance;
      config.attack_min_factor = newAttactMinFactor;
      config.attack_max_factor = newAttactMaxFactor;
  }

  function nextId() public returns(uint256) {
    last_id++;
    require(last_id > 0, "_next_id overflow detected");
    return last_id;
  }

  function random(uint num) public returns(uint) {

    uint newSeed = (lastSeed.add(block.timestamp)).mod(65537);

    lastSeed = newSeed;

    return newSeed.mod(num);
  }

  function isAlive(IPets.Pet memory pet) public view returns(bool) {
    uint current_time = block.timestamp;

    uint effect_hp_hunger = calcHungerHP(pet.last_fed_at, current_time);

    uint hp = max_health - effect_hp_hunger;

    return hp > 0;
  }

  function calcHungerHP(uint last_fed_at, uint current_time) internal view returns(uint) {
    // how long it's hungry?
    uint hungry_seconds = current_time - last_fed_at;
    uint hungry_points = hungry_seconds * max_hunger_points / hunger_to_zero;

    // calculates the effective hunger on hp, if pet hunger is 0
    uint effect_hp_hunger = 0;
    if (hungry_points >= max_hunger_points) {
        effect_hp_hunger = (hungry_points - max_hunger_points) / hunger_hp_modifier;
    }

    return effect_hp_hunger;
  }

  function getPets(uint _petId) public view returns(IPets.Pet memory) {
    return pets[_petId];
  }

  function isSleeping(IPets.Pet memory pet) public pure returns(bool) {
      return pet.last_fed_at > pet.last_awake_at;
  }

  function hasEnergy(IPets.Pet memory pet, uint minEnergy) public view returns(bool){
    uint awakeSeconds = block.timestamp - pet.last_awake_at;
    uint energy_bar = 100 - ((100 * awakeSeconds) / 1 days);
    return energy_bar > minEnergy;
  }

  function createPet(string memory _petName) public{
    bytes memory b = bytes(_petName);
    require(b.length >= 1, "name must have at least 1 character!");
    require(b.length <= 20, "name cannot exceed 20 chars");

    if(creation_tolerance > 0){
        uint256 last_created_date = 0;
        for(uint i = 0; i < last_id; i++){
          if(pets[i].id != 0)
            last_created_date = pets[i].created_at > last_created_date ? pets[i].created_at : last_created_date;  
        }

        uint256 last_creation_interval = block.timestamp - last_created_date;
        require(last_creation_interval > creation_tolerance, "You can't create another pet now");
    }

    uint newId = nextId();
    uint createdAt = block.timestamp;

    _safeMint(_msgSender(), newId);

    IPets.Pet memory p1 = IPets.Pet({
        id: newId,
        name: _petName,
        owner: _msgSender(),
        created_at: createdAt,
        death_at: 0,
        last_fed_at: createdAt,
        last_play_at: createdAt,
        last_shower_at: createdAt,
        last_bed_at: createdAt,
        last_awake_at: createdAt.add(creation_awake),

        // we are considering only 105 monsters, the type 105 is
        // monstereos devilish icon
        petType: ((createdAt.add(newId)).add(random(100)).mod(last_pet_type_id - 3))
    });

    pets[newId] = p1;

    emit MintPetNFT(_msgSender(), newId);
  }

  function destroyPet(uint _petId) public {
    require(_msgSender() == pets[_petId].owner, "Only owner can transfer pet");
    _burn(pets[_petId].id);
    delete pets[_petId];
    random(10);
  }

  function transferPet(uint _petId, address _newOwner) public {
    require(pets[_petId].id != 0, "Pet is not found or invalid pet");
    require(_msgSender() == pets[_petId].owner, "Only owner can transfer pet");

    transferFrom(_msgSender(), _newOwner, _petId);
    pets[_petId].owner = _newOwner;

    random(10);
    emit TransferPet(_msgSender(), _newOwner, _petId);
  }

  function transferFromPet(uint _petId, address owner, address _newOwner) public {
    require(pets[_petId].id != 0, "Pet is not found or invalid pet");
    require(owner == pets[_petId].owner, "Only owner can transfer pet");
    
    transferFrom(owner, _newOwner, _petId);
    pets[_petId].owner = _newOwner;

    random(10);
    emit TransferPet(_msgSender(), _newOwner, _petId);
  }

  function feedPet(uint _petId) public {
    require(pets[_petId].id != 0, "Pet is not found or invalid pet");
    require(_msgSender() == pets[_petId].owner, "Only owner can feed pet");

    require(isAlive(pets[_petId]), "dead don't eat");
    require(!isSleeping(pets[_petId]), "zzzzzz");

    bool canEat = (block.timestamp - pets[_petId].last_fed_at) > min_hunger_interval;
    require(canEat, "not hungry!");

    pets[_petId].last_fed_at = block.timestamp;

    // primer roller
    random(10);
  }

  function bedPet(uint _petId) public {
    require(pets[_petId].id != 0, "Pet is not found or invalid pet");
    require(isAlive(pets[_petId]), "dead don't sleep");
    require(!isSleeping(pets[_petId]), "already sleeping");

    bool canSleep = (block.timestamp - pets[_petId].last_awake_at) > min_awake_interval;
    require(canSleep, "not now!");

    pets[_petId].last_bed_at = block.timestamp;

    // primer roller
    random(10);
  }

  function awakePet(uint _petId) public {
    require(pets[_petId].id != 0, "Pet is not found or invalid pet");
    
    require(isAlive(pets[_petId]), "dead don't awake");
    require(!isSleeping(pets[_petId]), "already awake");

    bool canAwake = (block.timestamp - pets[_petId].last_bed_at) > min_sleep_period;
    require(canAwake, "zzzzzz");

    pets[_petId].last_awake_at = block.timestamp;

    // primer roller
    random(10);
  }

}
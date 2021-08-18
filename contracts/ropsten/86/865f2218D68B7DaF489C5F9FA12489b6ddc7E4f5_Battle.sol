//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "./IPets.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Battle is Ownable{

    // Battle Mode
    // uint8 private battleModeV1 = 1;
    // uint8 private battleModeV2 = 2;
    // uint8 private battleModeV3 = 3;

    struct PetStat {
        uint petID;
        uint petType;
        address player;
        uint hp;
    }

    struct PetsInBattle{
        address host;
        uint mode;
        uint startedAt;
        uint lastMoveAt;
        mapping(address => address[]) commits;
        mapping(address => PetStat[]) stats;
    }

    struct Element{
        uint id;
        uint8[3] ratios;
    }

    mapping(uint => Element[]) petTypes;

    IPets.PetConfig public config;

    PetsInBattle[] public battle;

    IPets public pet;

    constructor(address petAddress) {
        pet = IPets(petAddress);
        config = pet.config();
    }

    function updatePetAddress(address petAddress) public onlyOwner{
        pet = IPets(petAddress);
    }
    
    function findBattleByHost(address _host) internal view returns(bool, uint){
        for(uint i = 0; i < battle.length; i++){
            if(battle[i].host == _host){
                return(true, i);            
            }
        }
        return(false, 0);
    }

    function playerExists(address _player, address[] memory commit) internal pure returns(bool, uint){
       for (uint i =0; i < commit.length; i++) {
            if(commit[i] == _player)
                return (true, i);
        }
        return (false, 0);
    }

    function removePlayer(address _player) internal{
        (bool petsInBattle, uint index) = findBattleByHost(_player);
        if(petsInBattle){
            (bool playerInCommit, uint ix) = playerExists(_player, battle[index].commits[battle[index].host]);
            if(playerInCommit){
                delete battle[index].commits[battle[index].host][ix];
            }

            for (uint i =0; i < battle[index].stats[battle[index].host].length; i++) {
                if(battle[index].stats[battle[index].host][i].player == _player)
                    delete battle[index].stats[battle[index].host][i];
            }
        }
    }

    function setPetTypeElement(uint elementID) public onlyOwner {
        Element memory element;
        uint8[3] memory ratio = [0,6,3];
        element = Element({
            id:6,
            ratios: ratio
        });
        petTypes[elementID].push(element);
    }

    function createBattle(uint petId, uint mode) public {
        (bool isHostBattle,) = findBattleByHost(_msgSender());
        require(!isHostBattle, "you already host a battle!");
        IPets.Pet memory pets = pet.getPets(petId);
        require(pets.id != 0, "Pet not found or invalid pet");
        require(pets.owner == _msgSender(), "Only pet onwer can create battle");
        require(mode == 1 || mode == 2 || mode == 3, "invalid battle mode");

        config.battle_busy_arenas++;
        require(config.battle_busy_arenas <= config.battle_max_arenas, "all arenas are busy");
        
        uint256 idx = battle.length;
        battle.push();
        PetsInBattle storage p1 = battle[idx];
        p1.host = _msgSender();
        p1.mode = mode;

        joinBattle(petId,_msgSender());
    }

    function joinBattle(uint petId, address player) public {
        (bool isHostBattle, uint index) = findBattleByHost(_msgSender());
        require(isHostBattle, "battle not found for current host");
        (bool playerInCommit,) = playerExists(player, battle[index].commits[battle[index].host]);
        require(!playerInCommit, "player is already in this battle");
        require(battle[index].commits[battle[index].host].length < 2, "battle is already full of players");

        IPets.Pet memory pets = pet.getPets(petId);
        require(pets.id != 0, "Pet not found or invalid pet");

        battle[index].commits[battle[index].host].push(player);
        addPets(_msgSender(), player, petId);
    }

    function startBattle(uint petId, address player) public {
        (bool isHostBattle, uint index) = findBattleByHost(_msgSender());
        require(isHostBattle, "battle not found for current host");
        require(battle[index].startedAt == 0, "battle already started");
        require(battle[index].commits[battle[index].host].length == 2, "battle has not enough players");

        bool valid_reveal = false;
        uint i = 0;

        for(i = 0; i < battle[index].commits[battle[index].host].length; i++){
            if(battle[index].commits[battle[index].host][i] == player){
                addPets(_msgSender(), player, petId);
                valid_reveal = true;
            }
        }

        require(valid_reveal, "invalid reveal");

        if (i == battle[index].commits[battle[index].host].length) {
            battle[index].startedAt = block.timestamp;
            battle[index].lastMoveAt = block.timestamp;
        }        
    }

    function quickBattle(uint battleMode, address player, uint[] memory petIds) public {
        require(battleMode == 1 || battleMode == 2 || battleMode == 3, "invalid battle mode");
        // require(battle.length == battleMode, "pets selection is not valid");

        (bool isPetInBattle, uint index) = findBattleByHost(_msgSender());

        require(isPetInBattle, "player is already in another battle");

        // primer roller
        pet.random(10);

        // no battle or only started battles, starting one
        if (!isPetInBattle) {
            // check and increase busy arenas counter
            config.battle_busy_arenas++;
            require(config.battle_busy_arenas <= config.battle_max_arenas, "all arenas are busy");

            battle[index].commits[battle[index].host].push(player);

            for(uint i = 0; i < petIds.length; i++){
                addPets(battle[index].host, player, petIds[i]);
            }

            uint256 idx = battle.length;
            battle.push();
            PetsInBattle storage p1 = battle[idx];

            p1.host = player;
            p1.mode = battleMode;
            p1.startedAt = block.timestamp;
            p1.lastMoveAt = block.timestamp;
            
        } else {
            battle[index].commits[battle[index].host].push(player);
           
            for(uint i = 0; i < petIds.length; i++){
                addPets(battle[index].host, player, petIds[i]);
            }

            battle[index].startedAt = block.timestamp;
            battle[index].lastMoveAt = block.timestamp;
        }
    }

    function addPets(address host, address _player, uint _petId) internal {
        IPets.Pet memory pets = pet.getPets(_petId);
        require(pets.id != 0, "Pet not found or invalid pet");

        require(pet.isAlive(pets), "dead pets don't battle");
        require(!pet.isSleeping(pets), "sleeping pets don't battle");
        require(pet.hasEnergy(pets, 30), "pet has no energy for a battle");

        (bool isPetInBattle, uint ind) = findBattleByHost(host);

        require(isPetInBattle, "player is already in another battle");
            
        PetStat memory pStat = PetStat({
            petID: _petId,
            petType: pets.petType,
            player: _player,
            hp: 100
        });
        battle[ind].stats[battle[ind].host].push(pStat);
    }

    function battleLeave(address _player) public {
        (bool isPetInBattle, uint index) = findBattleByHost(_msgSender());
        require(isPetInBattle, "battle not found for current host");

        require(battle[index].startedAt == 0, "battle already started");
        (bool isPlayer, uint ind) = playerExists(_player, battle[index].commits[battle[index].host]);
        require(isPlayer, "player not in this battle");

        // remove pets from battle
        PetStat[] memory pStat = battle[index].stats[battle[index].host];
        for(uint i = 0; i < pStat.length; i++){
            delete battle[index].stats[battle[ind].host][i];
        }

        (bool isInBattle, uint battleIndex) = findBattleByHost(_player);
        
        if (isInBattle) {
            delete battle[battleIndex];
        }

        if (_player == _msgSender()) {
            delete battle[index];
            config.battle_busy_arenas--;
        } else {
            removePlayer(_player);
        }
    }

    mapping(address => uint8[]) alivePets;
    address public winner;

    function battleAttack(address host,address player, uint pet_id, uint pet_enemy_id, uint element_id) public {
        bool isPetInBattle;
        uint index;
        (isPetInBattle, index) = findBattleByHost(host);
        require(isPetInBattle, "battle not found for current host");
        // check and rotate turn only if player is not idle
        bool is_idle = (block.timestamp - battle[index].lastMoveAt) > config.battle_idle_tolerance;

        require(battle[index].host == player || is_idle, "its not your turn");
       
        validElement(index, pet_id, player, element_id, pet_enemy_id);
        
        // check battle end
        uint playersAlive = 0;
        for(uint i = 0; i < alivePets[player].length; i++){
            if (alivePets[player][i] > 0) {
                playersAlive++;
                winner = player;
            }
        }

        // modify stats and goes to next turn or end battle
        if (playersAlive > 1) {
            battle[index].lastMoveAt = block.timestamp;
        } else {
            // we need an action here?
            battleFinish(host);
        }
    }

    function validElement(uint index, uint petId, address player, uint elementID, uint petEnemyId) internal {

        // get current pet and enemy types
        uint i;
        uint pet_type = 0;
        uint pet_enemy_type_id = 0;
        bool valid_pet = false;
        PetStat[] memory stats = battle[index].stats[battle[index].host];
        for (i =0; i < stats.length; i++) {
            if (stats[i].petID == petId) {
                require(stats[i].player == player, "you cannot control this monster");
                require(stats[i].hp > 0, "this monster is dead");
                pet_type = stats[i].petType;
                valid_pet = true;
            } else if (stats[i].petID == petEnemyId) {
                pet_enemy_type_id = stats[i].petType;
            }
        }

        require(valid_pet, "invalid attack");
        Element[] memory attack_pet_types = petTypes[pet_type]; 
        bool valid_element = false;
        for (i = 0; i < attack_pet_types.length; i++) {
            if (attack_pet_types[i].id == elementID) {
                valid_element = true;
                break;
            }
        }
        require(valid_element, "invalid attack element");
        // cross ratio elements to enemy pet elements
        uint ratio = 5; // default ratio
        for (i = 0; i < petTypes[pet_enemy_type_id].length; i++) {
            uint type_ratio = attack_pet_types[elementID].ratios[petTypes[pet_enemy_type_id][i].id];
            ratio = type_ratio > ratio ? type_ratio : ratio;
        }

        uint factor = pet.random(config.attack_max_factor + 1 - config.attack_min_factor) + config.attack_min_factor;

        // damage based on element ratio and factor
        uint damage = factor * ratio / 10;

        // updates pet hp and finish attack turn
        for (i = 0; i < stats.length; i++) {
            if (stats[i].petID == petEnemyId) {
                stats[i].hp = damage > stats[i].hp ? 0 : stats[i].hp - damage;
            }
            // update alive pets
            uint8 alive_counter = stats[i].hp > 0 ? 1 : 0;
            alivePets[stats[i].player].push(alive_counter);
        }
    }

    function battleFinish(address host) internal {
        (bool isPetInBattle, uint index) = findBattleByHost(host);
        require(isPetInBattle, "battle not found for current host");

        // removes pets from in battle status table
        for (uint i =0; i < battle[index].stats[battle[index].host].length; i++) {
            (bool petInBattle,) = findBattleByHost(host);
            if(petInBattle)
                delete battle[index].stats[battle[index].host][i];
        }

        // removes players from in battle status table
        for(uint i = 0; i < battle[index].commits[battle[index].host].length; i++){
            delete battle[index].commits[battle[index].host][i];
        }

        delete battle[index];

        // decrease busy arenas counter
        config.battle_busy_arenas--;

        pet.random(10);
    }

}
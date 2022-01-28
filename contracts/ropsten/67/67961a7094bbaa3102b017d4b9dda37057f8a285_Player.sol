/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.7 <0.9.0;

contract Character {
    address public owner;
    string public name;
    string public race;
    string public class;
    uint8 public health;

    function setHealth(uint8 _damage) external virtual {
        if (_damage >= health){
            health = 0;
        } else {
            health -= _damage;
        }
    }
}

contract Weapon {
    string public weapon;
    uint8 public attack;
}

contract Player is Character, Weapon {
    uint8 public level;
    uint8 public score;
    string defeatedBy;
    address[] defeatedPlayers;

    event Attacked(Player player, uint8 damage, uint8 healthLeft);
    event AttackedBy(Player player, uint8 damage, uint8 healthLeft);
    event Defeated(Player player, uint8 newLevel, uint8 newScore);
    event DefeatedBy(Player player, uint8 damage);
    event Cured(uint8 newHealth, uint8 newScore);
    event ImprovedAttack(uint newAttack, uint8 newScore);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not owner");
        _;
    }

    modifier alive() {
        require(health > 0, "You are already dead");
        _;
    }

    modifier hasScore() {
        require(score > 0, "Your score is zero");
        _;
    }

    constructor(string memory _name, string memory _race, string memory _class, string memory _weapon) {
       owner = msg.sender;
       name = _name;
       race = _race;
       class = _class;
       weapon = _weapon;
       health = 100;
       attack = 10;
       level = 1;
       score = 0;
       defeatedBy = "was not defeated";
    }

    function setHealth(uint8 _damage, Player _attacker) public virtual {
        if (_damage >= health){
            health = 0;
            emit DefeatedBy(_attacker, _damage);
            defeatedBy = _attacker.name();
        } else {
            health -= _damage;
            emit AttackedBy(_attacker, _damage, health);
        }
    }

    function attackPlayer(address _otherPlayer) public onlyOwner alive {
        Player otherPlayer = Player(_otherPlayer);
        otherPlayer.setHealth(attack, Player(msg.sender));
        uint8 otherPlayerHealth = otherPlayer.health();
        emit Attacked(otherPlayer, attack, otherPlayerHealth);
        if (otherPlayerHealth == 0) {
            defeatedPlayers.push(_otherPlayer);
            level += 1;
            score += 5;
            emit Defeated(otherPlayer, level, score);
        }
    }

    function getDefeatedBy() public view returns(string memory) {
        return defeatedBy;
    }

    function getDefeatedPlayers() public view returns(address[] memory) {
        return defeatedPlayers;
    }

    function cure() public onlyOwner alive hasScore {
        health += 5;
        score -= 1;
        emit Cured(health, score);
    }

    function improveAttack() public onlyOwner alive hasScore {
        attack += 1;
        score -= 1;
        emit ImprovedAttack(health, score);
    }
}
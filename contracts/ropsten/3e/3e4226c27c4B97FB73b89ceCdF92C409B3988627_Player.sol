/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

contract Character{
    address public owner;
    string public name;
    string public race;
    string public class;
    uint8 public health;
    uint8 public exp;

}

contract weapon{
    string public weaponName;
    uint8 public force;
}

interface Armor_coin_not_rare{
    function transfer(address, uint8)external;
}

interface Armor_coin_rare{
    function transfer_rare(address, uint8)external;
}


contract Player is Character, weapon{
    uint8 public lvl;
    uint8 public points;
    string public wasDefeated;
    string[] private defeatedPlayers;
    Armor_coin_not_rare coin = Armor_coin_not_rare(0x44478632ed107eACf0ee077e36240C508f0B5AEF);
    Armor_coin_rare rare_coin = Armor_coin_rare(0x0E8258acc23d092e27249d5a46CEBc03dde7aEC4);

    constructor(string memory _name, string memory _race, string memory _class, string memory _weaponName){
        owner = msg.sender;
        name = _name;
        race = _race;
        class = _class;
        weaponName = _weaponName;
        health = 100;
        force = 10;
        lvl = 1;
        points = 0;
    }

    modifier onlyOwner()
    {
    require(msg.sender == owner);
    _;
    } 

    modifier havePoints(){
    require (points > 0);
    _;
    } 

    function cure() public onlyOwner havePoints{
        health += 5;
        points -= 1;
    }

    function imporoveAttack() public onlyOwner havePoints{
        force += 1;
        points -= 1;
    }

    function farmZombies() public onlyOwner{
        require(health > 0, "You are dead");
        if (health > 0){
            uint hashBlock = uint(blockhash(block.number));
            uint hashADr = uint(keccak256(abi.encode(msg.sender)));
            uint hashTime = uint(keccak256(abi.encode(block.timestamp)));
            uint result = uint8(uint( keccak256( abi.encode( hashBlock%100 + hashADr%100 + hashTime%100)))%10);
            if (result < 8) {
                health -= 1;
            }
            else{ 
                health -= 4;
                uint result2 = uint8(uint( keccak256( abi.encode( hashBlock%100 + hashADr%100 + hashTime%100)))%100);
                if (result2 > 94 && result2 < 99) coin.transfer(owner, 10);
                if (result2 > 99) rare_coin.transfer_rare(owner, 5);
            }
            exp += 5;
            if (exp == 100){
                lvl += 1;
                if (lvl % 10 == 0) points += 10;
                else points += 5;
                exp = 0;
            }
        }
    }
}
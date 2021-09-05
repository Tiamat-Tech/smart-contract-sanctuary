// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
/*

  _______________________________________
 /                                       \
/   _   _   _                 _   _   _   \
|  | |_| |_| |   _   _   _   | |_| |_| |  |
|   \   _   /   | |_| |_| |   \   _   /   |
|    | | | |     \       /     | | | |    |
|    | |_| |______|     |______| |_| |    |
|    |              ___              |    |
|    |  _    _    (     )    _    _  |    |
|    | | |  |_|  (       )  |_|  | | |    |
|    | |_|       |       |       |_| |    |
|   /            |_______|            \   |
|  |___________________________________|  |
\ CASTLESDAO presents: Castles Gen One    /
 \_______________________________________/

*/

interface LootInterface {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract CastlesLoot is ERC721Enumerable, ReentrancyGuard, Ownable {

    uint256 public lootersPrice = 10000000000000000; // 0.01 ETH
    uint256 public price = 300000000000000000; //0.3 ETH
    bool public lockedForLooters = true;

    // This will be locked for some time, to allow looters to get their castle first
    function flipLockedForLooters() public onlyOwner {
        lockedForLooters = !lockedForLooters;
    }

    function setLootersPrice(uint256 newPrice) public onlyOwner {
        lootersPrice = newPrice;
    }

    function setPublicPrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
    }

    //Loot Contract
    address public lootAddress = 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;
    LootInterface public lootContract = LootInterface(lootAddress);

    string[] private warriors = [       
        "Champion",
        "Dragon",
        "Frog",
        "Ghost",
        "Golem",
        "King",
        "Witch",
        "Punk Alien",
        "Punk Ape",
        "Skeleton",
        "Wizard"
    ];

    string[] private skillTypes = [
        "archery",
        "damage",
        "attack speed",
        "gold generation",
        "defense",
        "agility",
        "intelligence",
        "charisma",
        "luck",
        "fear"
    ];

    string[] private protectedNames = [
        "Defended",
        "Protected",
        "Guarded",
        "Shielded",
        "Safeguarded",
        "Fortified",
        "Secured"
    ];

    string[] private races = [
        "Goblin",
        "Human",
        "Dwarf",
        "Elf",
        "Half-Elf",
        "Undead",
        "Orc",
        "Imp",
        "Ape",
        "Faerie",
        "Troll",
        "Angel",
        "Djinn",
        "Shade",
        "Shapeshifter",
        "Spirit",
        "Golem",
        "Dog",
        "Cat",
        "Eagle",
        "Raven",
        "Halfling",
        "Leoning",
        "Triton",
        "Demon",
        "Centaur",
        "Loxodon",
        "Minotaur",
        "Vedalken",
        "Merfolk",
        "Dark-Elf",
        "Balrog",
        "Ent"
    ];

    string[] private backgrounds = [
        "Beggar",
        "Mercenary",
        "Scholar",
        "Gambler",
        "Wizard",
        "Alchemist",
        "Soldier",
        "Merchant",
        "Warrior",
        "Noble",
        "Healer",
        "Seer",
        "Acolyte",
        "Legionnaire",
        "Functionary",
        "Charlatan",
        "Crafter",
        "Spy",
        "Criminal",
        "Investigator",
        "Traveler",
        "Fisher",
        "Gambler",
        "Gladiator",
        "Artisan",
        "Hermit",
        "Marine",
        "Sailor",
        "Assassin",
        "King",
        "Queen"
    ];

    string[] private castleTypes = [
        "Fortress",
        "Tower",
        "Castle",
        "Prison",
        "Guard",
        "Defense",
        "Stronghold",
        "Citadel",
        "Palace",
        "Lair",
        "House",
        "Barracks",
        "Dome",
        "Fort",
        "Alcazar",
        "Acropolis",
        "Garrison"
    ];

    string[] private castleTitles = [
        "of Doom",
        "of Sweetness",
        "of Treachery",
        "of Happiness",
        "of Terror",
        "of Ethereum",
        "of the brave",
        "of Gold",
        "of Silver",
        "of Diamonds",
        "of the Divine",
        "of the orcs",
        "of the elfs",
        "of Assassins",
        "of Wizards",
        "of Trolls",
        "of Fire",
        "of Pleasure",
        "of Death",
        "of Life",
        "of the Big Bang",
        "of Quantum Forces",
        "of Despair",
        "of Magic",
        "of Dragons",
        "of the cats",
        "of the Queen",
        "of the DAO",
        "of the King",
        "of the Emperor",
        "of the Ice",
        "of the Ice King",
        "of the Phantoms",
        "of the Sun",
        "of the Lich",
        "of Blood",
        "of the Djinn",
        "of Golems"
    ];

    

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory) {
        return string(abi.encodePacked(bytes(_a), bytes(_b)));
    }
   
    function compareStrings(string memory a, string memory b) public view returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    // Returns a random item from the list, always the same for the same token ID
    function pluck(uint256 tokenId, string memory keyPrefix, string[] memory sourceArray) internal view returns (string memory) {
        uint256 rand = random(string(abi.encodePacked(keyPrefix, toString(tokenId))));

        string memory output = sourceArray[rand % sourceArray.length];
        
        return output;
    }

    // 0 - 99 + 10 for warrior
    function getDefense(uint256 tokenId) public view returns (uint256) {
        // Random defense + if has warrior + 10
        uint256 rand = random(string(abi.encodePacked("DEFENSE", toString(tokenId))));
        uint256 numberDefense = rand % 99;

        string memory warrior = getWarrior(tokenId);

        // If not has warrior, return defense
        if (compareStrings(warrior, "none")) {
            return numberDefense;
        }

        // Has warrior, return defense + 10
        return numberDefense  + 10;
    }

    // 0 - 25
    function getGoldGeneration(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        uint256 rand = random(string(abi.encodePacked("GOLD_GENERATION", toString(tokenId))));
        uint256 numberGoldGeneration = rand % 25;

        return numberGoldGeneration;
    }

    // 1-255
    function getCapacity(uint256 tokenId) public view returns (uint256) {
        uint256 rand = random(string(abi.encodePacked("CAPACITY", toString(tokenId))));
        uint256 capacity = rand % 254;

        return capacity + 1;
    }

    // 1 - 20
    function getSkillAmount(uint256 tokenId) public view returns (uint256) {
        uint256 rand = random(string(abi.encodePacked("SKILL_AMOUNT", toString(tokenId))));
        uint256 skillAmount = rand % 20;

        return skillAmount + 1;
    }

    // 1-10
    function getRarityNumber(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        uint256 goldGeneration = getGoldGeneration(tokenId);
        uint256 defense = getDefense(tokenId);
        uint256 capacity = getDefense(tokenId);
        uint256 skillAmount = getSkillAmount(tokenId);

        uint256 rarity = 0;

        // Good gold generation
        if (goldGeneration > 10) {
            rarity +=1;
            if (goldGeneration >= 15) {
                rarity+=1;
            }
        }
        // if defense 
        if(defense > 70) {
            rarity +=1;
            if (defense > 80) {
                rarity +=1;

                if (defense > 90) {
                    rarity+=1;
                }
            }
        }

        // has capacity
        if (capacity > 150) {
            rarity +=1;

            if (capacity > 220) {
                rarity+=1;
            }
        }

        // has skillz
        if (skillAmount > 10) {
            rarity +=1;

            if (skillAmount >= 15) {
                rarity+=1;
            }
            if (skillAmount >= 20) {
                rarity+=1;
            }
        }

        return rarity;
    }

    function getRarity(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        uint256 rarity = getRarityNumber(tokenId);

        if (rarity > 6) {
            return "Divine";
        }

        if (rarity > 4) {
            return "Mythic";
        }

        if (rarity > 2) {
            return "Rare";
        }

        return "Common";
    }

    function getSkillType(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "SKILL", skillTypes);
    }

    function getCastleType(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "CASTLE_TYPE", castleTypes);
    }

    // Visible 

    function getWarrior(uint256 tokenId) public view returns (string memory) {
        uint256 rand = random(string(abi.encodePacked("WARRIOR_PROBABILITY", toString(tokenId))));
        uint256 warriorProbability = rand % 99;
        if (warriorProbability < 30 ) {
            return pluck(tokenId, "WARRIOR", warriors);
        } 
        return "none";
    }

    function getWarriorName(uint256 tokenId) public view returns (string memory) {
        string memory warrior = getWarrior(tokenId);
        
        if (compareStrings(warrior, "none")) {
            return "none";
        }

        string memory background = pluck(tokenId, "WARRIOR_BACKGROUND", backgrounds);
        return string(abi.encodePacked(background, " ", warrior));
    }

    function getName(uint256 tokenId) public view returns (string memory) {
        string memory warrior = getWarrior(tokenId);
        string memory castleType = getCastleType(tokenId);
       
        // If does not have warrior
        if (compareStrings(warrior, "none")) {
            // Calculate the castle title
             uint256 rand = random(string(abi.encodePacked("CASTLE_TITLE_PROBABILITY", toString(tokenId))));
            uint256 withOwnerName = rand % 99;
            string memory castleTitle = pluck(tokenId, "CASTLE_TITLE", castleTitles);

            if (withOwnerName < 70 ) {
                string memory race = pluck(tokenId, "CASTLE_TITLE_RACE", races);
                string memory background = pluck(tokenId, "CASTLE_TITLE_BACKGROUND", backgrounds);
                castleTitle = string(abi.encodePacked("of the ", background, " ", race));
            } 

            return string(abi.encodePacked(castleType, " ", castleTitle));
        }

        string memory warriorName = getWarriorName(tokenId);

        return string(abi.encodePacked(pluck(tokenId, "PROTECTED_NAME", protectedNames), " ", castleType, " of the ", warriorName));
    }

    string[] private traitCategories = [
        "Name",
        "CastleType",
        "Defense",
        "SkillType",
        "SkillAmount",
        "GoldGeneration",
        "WarriorName",
        "Warrior",
        "Capacity",
        "RarityNumber",
        "Rarity"
    ];
    
    function traitsOf(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string[11] memory traitValues = [
            getName(tokenId),
            getCastleType(tokenId),
            toString(getDefense(tokenId)),
            getSkillType(tokenId),
            toString(getSkillAmount(tokenId)),
            toString(getGoldGeneration(tokenId)),
            getWarriorName(tokenId),
            getWarrior(tokenId),
            toString(getCapacity(tokenId)),
            toString(getRarityNumber(tokenId)),
            getRarity(tokenId)
        ];

        string memory resultString = "[";
        for (uint8 j = 0; j < traitCategories.length; j++) {
        if (j > 0) {
            resultString = strConcat(resultString, ", ");
        }
        resultString = strConcat(resultString, '{"trait_type": "');
        resultString = strConcat(resultString, traitCategories[j]);
        resultString = strConcat(resultString, '", "value": "');
        resultString = strConcat(resultString, traitValues[j]);
        resultString = strConcat(resultString, '"}');
        }
        return strConcat(resultString, "]");
    }


    /**
     * @dev Base URI for computing {tokenURI}. Empty by default, can be overriden
     * in child contracts.
     */
    function _baseURI() override internal view virtual returns (string memory) {
        return "https://castles-nft.vercel.app/api/castle/";
    }

    function mint(uint256 tokenId) public payable nonReentrant {
        if (lockedForLooters) {
            require(tokenId > 8000 && tokenId <= 9900, "Token ID invalid");
        } else {
            require(tokenId > 0 && tokenId <= 9900, "Token ID invalid");
        }
        require(price <= msg.value, "Ether value sent is not correct");
        _safeMint(_msgSender(), tokenId);
    }

 

    function mintWithLoot(uint256 lootId) public payable nonReentrant {
        require(lockedForLooters, "Mint with loot period has finished, mint normally.");
        require(lootId > 0 && lootId <= 8000, "Token ID invalid");
        require(lootersPrice <= msg.value, "Ether value sent is not correct");
        require(lootContract.ownerOf(lootId) == msg.sender, "Not the owner of this loot");
        _safeMint(_msgSender(), lootId);
    }

   

    // Allow the DAO to claim in case some item remains unclaimed in the future
    function ownerClaim(uint256 tokenId) public nonReentrant onlyOwner {
        require(tokenId <= 10000, "Token ID invalid");
        _safeMint(owner(), tokenId);
    }

    function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    constructor() ERC721("CastlesLootGenOne", "CastlesLootGenOne") Ownable() {}
}
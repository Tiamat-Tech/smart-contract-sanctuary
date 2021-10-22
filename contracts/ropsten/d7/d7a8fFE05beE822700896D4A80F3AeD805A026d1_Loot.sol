pragma solidity ^0.8.0;
import "@imtbl/imx-contracts/contracts/Mintable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../library/Base64.sol";


contract Loot is ERC721Enumerable, ReentrancyGuard, Mintable {
    uint256 public next_tokenId;

    string[] private weapons = [
    "Warhammer",
    "Quarterstaff",
    "Maul",
    "Mace",
    "Club",
    "Katana",
    "Falchion",
    "Scimitar",
    "Long Sword",
    "Short Sword",
    "Ghost Wand",
    "Grave Wand",
    "Bone Wand",
    "Wand",
    "Grimoire",
    "Chronicle",
    "Tome",
    "Book"
    ];


    string[] private rings = [
    "Gold Ring",
    "Silver Ring",
    "Bronze Ring",
    "Platinum Ring",
    "Titanium Ring"
    ];

    string[] private suffixes = [
    "of Power",
    "of Giants",
    "of Titans",
    "of Skill",
    "of Perfection",
    "of Brilliance",
    "of Enlightenment",
    "of Protection",
    "of Anger",
    "of Rage",
    "of Fury",
    "of Vitriol",
    "of the Fox",
    "of Detection",
    "of Reflection",
    "of the Twins"
    ];

    string[] private namePrefixes = [
    "Agony", "Apocalypse", "Armageddon", "Beast", "Behemoth", "Blight", "Blood", "Bramble",
    "Brimstone", "Brood", "Carrion", "Cataclysm", "Chimeric", "Corpse", "Corruption", "Damnation",
    "Death", "Demon", "Dire", "Dragon", "Dread", "Doom", "Dusk", "Eagle", "Empyrean", "Fate", "Foe",
    "Gale", "Ghoul", "Gloom", "Glyph", "Golem", "Grim", "Hate", "Havoc", "Honour", "Horror", "Hypnotic",
    "Kraken", "Loath", "Maelstrom", "Mind", "Miracle", "Morbid", "Oblivion", "Onslaught", "Pain",
    "Pandemonium", "Phoenix", "Plague", "Rage", "Rapture", "Rune", "Skull", "Sol", "Soul", "Sorrow",
    "Spirit", "Storm", "Tempest", "Torment", "Vengeance", "Victory", "Viper", "Vortex", "Woe", "Wrath",
    "Light's", "Shimmering"
    ];

    string[] private nameSuffixes = [
    "Bane",
    "Root",
    "Bite",
    "Song",
    "Roar",
    "Grasp",
    "Instrument",
    "Glow",
    "Bender",
    "Shadow",
    "Whisper",
    "Shout",
    "Growl",
    "Tear",
    "Peak",
    "Form",
    "Sun",
    "Moon"
    ];

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function getWeapon(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "WEAPON", weapons);
    }

    function getRing(uint256 tokenId) public view returns (string memory) {
        return pluck(tokenId, "RING", rings);
    }

    function pluck(uint256 tokenId, string memory keyPrefix, string[] memory sourceArray) internal view returns (string memory) {
        uint256 rand = random(string(abi.encodePacked(keyPrefix, toString(tokenId))));
        string memory output = sourceArray[rand % sourceArray.length];
        uint256 greatness = rand % 21;
        if (greatness > 14) {
            output = string(abi.encodePacked(output, " ", suffixes[rand % suffixes.length]));
        }
        if (greatness >= 19) {
            string[2] memory name;
            name[0] = namePrefixes[rand % namePrefixes.length];
            name[1] = nameSuffixes[rand % nameSuffixes.length];
            if (greatness == 19) {
                output = string(abi.encodePacked('"', name[0], ' ', name[1], '" ', output));
            } else {
                output = string(abi.encodePacked('"', name[0], ' ', name[1], '" ', output, " +1"));
            }
        }
        return output;
    }

    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        string[5] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

        parts[1] = getWeapon(tokenId);

        parts[2] = '</text><text x="10" y="40" class="base">';


        parts[3] = getRing(tokenId);

        parts[4] = '</text></svg>';

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4]));

        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Bag #', toString(tokenId), '", "description": "Loot is randomized adventurer gear generated and stored on chain. Come on.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }

    function claim() public nonReentrant {
        //        require(tokenId > 0 && tokenId < 7778, "Token ID invalid");
        uint256 tokenId = next_tokenId;
        _safeMint(_msgSender(), tokenId);
        next_tokenId++;
    }

    function ownerClaim(uint256 tokenId) public nonReentrant onlyOwner {
        //        require(tokenId > 7777 && tokenId < 8001, "Token ID invalid");
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

    constructor(address _owner,address _imx) ERC721("Loot", "LOOT") Mintable(_owner, _imx) {}


    function _mintFor(
        address to,
        uint256 id,
        bytes calldata blueprint
    ) internal virtual override {
        _safeMint(to, id);

        // TODO: make sure only Immutable X can call this function
        // TODO: mint the token!
    }
}
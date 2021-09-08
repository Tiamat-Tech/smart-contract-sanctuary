// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CatLoot is ERC721Enumerable, ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    uint256 public catLootPrice = 0.05 ether;
    address payable public devAddr;
    using Address for address;

        string[] private weapons = [
        "Claws",
        "Teeth",
        "Laser Eyes",
        "Catnip Gun",
        "Knife",
        "Mittens",
        "Hairball",
        "Projectile Vomit",
        "Boxing Gloves",
        "Tail Spikes",
        "Loud Meow",
        "Catarang",
        "Mousetrap",
        "Headbutt",
        "Hair Spikes",
        "Hiss",
        "Growl",
        "Sharp Whiskers"
    ];
    
    string[] private catFur = [
        "Thick Fur",
        "Soft Fur",
        "Flaming Fur",
        "Normal Fur",
        "Reflective Fur",
        "Radioactive Fur",
        "Rainbow Fur",
        "Leather Fur",
        "Iron Fur",
        "Devil Fur",
        "Holy Fur",
        "Matted Fur",
        "Sharp Fur",
        "Icy Fur",
        "Shining Fur"
    ];
    
    string[] private headArmor = [
        "Halo",
        "Devil Horns",
        "Ski Mask",
        "Ear Muffs",
        "Cowboy Hat",
        "Flaming Crown",
        "3D Glasses",
        "VR Headset",
        "Headphones",
        "Plate Helmet",
        "Baseball Hat",
        "Hardhat",
        "Wizard Hat",
        "Dunce Cap",
        "Lion's Mane"
    ];
    
    string[] private waistYarn = [
        "Utility Yarn",
        "Metal Yarn",
        "Colorful Yarn",
        "Spaghetti Noodle",
        "Holy Yarn",
        "Devil Yarn",
        "Leather Yarn",
        "Studded Leather Yarn",
        "Bedazzled Yarn",
        "Bloodstained Yarn",
        "Magic Yarn",
        "Normal Yarn",
        "Radioactive Yarn",
        "Golden Yarn",
        "Old Yarn"
    ];
    
    string[] private footBooties = [
        "Nail Caps",
        "Silicone Booties",
        "Metal Booties",
        "Rainbow Booties",
        "Leather Booties",
        "Cloth Booties",
        "Evil Booties",
        "Holy Booties",
        "Radioactive Booties",
        "Bloodstained Booties",
        "Golden Booties",
        "Normal Booties",
        "Shiny Booties",
        "Old Booties",
        "Invisible Booties"
    ];
    
    string[] private catAccessory = [
        "Yo-yo",
        "Milk Jug",
        "Squeaky Toy",
        "Cigarette",
        "Scratching Post",
        "Purse",
        "Backpack",
        "Invisibility Cloak",
        "Catnip Joint",
        "Laser Pointer",
        "Hairbrush",
        "Box of Treats",
        "Cat Grass",
        "Angel Wings",
        "Devil Wings"
    ];
    
    string[] private necklaces = [
        "Collar",
        "Chain",
        "Bowtie"
    ];
    
    string[] private earrings = [
        "Gold Earring",
        "Silver Earring",
        "Bronze Earring",
        "Platinum Earring",
        "Titanium Earring"
    ];
    
    string[] private suffixes = [
        "of the Nine",
        "of Purrgatory",
        "of the Alley",
        "of Zoomies",
        "of Perfection",
        "of the Celestial",
        "of Enlightenment",
        "of Protection",
        "of the Holy",
        "of the Devil",
        "of Sloth",
        "of Stealth",
        "of the Feline",
        "of Revenge",
        "of Reflection",
        "of the One"
    ];
    
    string[] private namePrefixes = [
        "Fuego's", "Nebula's", "Turkel's", "Doof's", "Cheeto's", "Sprinkle's", "Pumpernickel's", "Philip's", 
        "Suhgarro's", "Aster's", "Jerry's", "Timothee's", "Scorboth's"
    ];
    
    string[] private nameSuffixes = [
        "Blessing",
        "Favor",
        "Bite",
        "Luck",
        "Speed",
        "Revenge",
        "Wrath",
        "Roar",
        "Blade",
        "Shadow",
        "Whisper",
        "Hiss",
        "Growl",
        "Glare",
        "Boost",
        "Banner",
        "Gaze",
        "Anger"
    ];
    
    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function withdrawDevFunds() public onlyOwner nonReentrant {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setDev(address payable _devAddr) external onlyOwner {
        devAddr = _devAddr;
    }
    
    function getWeapon(uint256 tokenId) public view returns (string memory) {
        uint256 _currentSupply = totalSupply().sub(1);
        require(tokenId <= _currentSupply, "CatLoot not minted yet");
        return pluck(tokenId, "WEAPON", weapons);
    }
    
    function getFur(uint256 tokenId) public view returns (string memory) {
        uint256 _currentSupply = totalSupply().sub(1);
        require(tokenId <= _currentSupply, "CatLoot not minted yet");
        return pluck(tokenId, "FUR", catFur);
    }
    
    function getHead(uint256 tokenId) public view returns (string memory) {
        uint256 _currentSupply = totalSupply().sub(1);
        require(tokenId <= _currentSupply, "CatLoot not minted yet");
        return pluck(tokenId, "HEAD", headArmor);
    }
    
    function getWaistYarn(uint256 tokenId) public view returns (string memory) {
        uint256 _currentSupply = totalSupply().sub(1);
        require(tokenId <= _currentSupply, "CatLoot not minted yet");
        return pluck(tokenId, "WAISTYARN", waistYarn);
    }

    function getFootBooties(uint256 tokenId) public view returns (string memory) {
        uint256 _currentSupply = totalSupply().sub(1);
        require(tokenId <= _currentSupply, "CatLoot not minted yet");
        return pluck(tokenId, "BOOTIES", footBooties);
    }
    
    function getCatAccessory(uint256 tokenId) public view returns (string memory) {
        uint256 _currentSupply = totalSupply().sub(1);
        require(tokenId <= _currentSupply, "CatLoot not minted yet");
        return pluck(tokenId, "ACCESSORY", catAccessory);
    }
    
    function getNeck(uint256 tokenId) public view returns (string memory) {
        uint256 _currentSupply = totalSupply().sub(1);
        require(tokenId <= _currentSupply, "CatLoot not minted yet");
        return pluck(tokenId, "NECK", necklaces);
    }
    
    function getEarring(uint256 tokenId) public view returns (string memory) {
        uint256 _currentSupply = totalSupply().sub(1);
        require(tokenId <= _currentSupply, "CatLoot not minted yet");
        return pluck(tokenId, "EARRING", earrings);
    }
    
    function pluck(uint256 tokenId, string memory keyPrefix, string[] memory sourceArray) internal view returns (string memory) {
        uint256 _currentSupply = totalSupply().sub(1);
        require(tokenId <= _currentSupply, "CatLoot not minted yet");
        
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
        string[17] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

        parts[1] = getWeapon(tokenId);

        parts[2] = '</text><text x="10" y="40" class="base">';

        parts[3] = getFur(tokenId);

        parts[4] = '</text><text x="10" y="60" class="base">';

        parts[5] = getHead(tokenId);

        parts[6] = '</text><text x="10" y="80" class="base">';

        parts[7] = getWaistYarn(tokenId);

        parts[8] = '</text><text x="10" y="100" class="base">';

        parts[9] = getFootBooties(tokenId);

        parts[10] = '</text><text x="10" y="120" class="base">';

        parts[11] = getCatAccessory(tokenId);

        parts[12] = '</text><text x="10" y="140" class="base">';

        parts[13] = getNeck(tokenId);

        parts[14] = '</text><text x="10" y="160" class="base">';

        parts[15] = getEarring(tokenId);

        parts[16] = '</text></svg>';

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7], parts[8]));
        output = string(abi.encodePacked(output, parts[9], parts[10], parts[11], parts[12], parts[13], parts[14], parts[15], parts[16]));
        
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Bag #', toString(tokenId), '", "description": "Loot is randomized adventurer gear generated and stored on chain. Stats, images, and other functionality are intentionally omitted for others to interpret. Feel free to use Loot in any way you want.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }

    function claim(uint256 _numberOfCatLoot) public payable nonReentrant {
        require(msg.value != 0, "Payment required");
        require(totalSupply() < 10001, "All CatLoot has been minted.");
        require(totalSupply().add(1) <= 10001, "Over supply");
        require(_numberOfCatLoot != 0, "Min 1 CatLoot per txn");
        require(_numberOfCatLoot <= 10, "Max 10 CatLoot per txn");
        require(catLootPrice.mul(_numberOfCatLoot) == msg.value, "Incorrect ETH value");
        
        devAddr.transfer(msg.value);

        for (uint256 i = 0; i < _numberOfCatLoot; i++) {
            uint256 tokenID = totalSupply();
            _safeMint(_msgSender(), tokenID);
            }
        
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
    
    constructor() ERC721("CatLoot", "CATLOOT") Ownable() {
        devAddr = payable(msg.sender);
    }
}

library Base64 {
    string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';
        
        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)
            
            // prepare the lookup table
            let tablePtr := add(table, 1)
            
            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
            
            // result ptr, jump over length
            let resultPtr := add(result, 32)
            
            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
               dataPtr := add(dataPtr, 3)
               
               // read 3 bytes
               let input := mload(dataPtr)
               
               // write 4 characters
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
               resultPtr := add(resultPtr, 1)
            }
            
            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }
        
        return result;
    }
}
/*

 _______  _______           _______ _________ _______  _        _______ 
(  ____ \(  ____ )|\     /|(  ____ \\__   __/(  ___  )( \      (  ____ \   (for Adventurers) 
| (    \/| (    )|( \   / )| (    \/   ) (   | (   ) || (      | (    \/
| |      | (____)| \ (_) / | (_____    | |   | (___) || |      | (_____ 
| |      |     __)  \   /  (_____  )   | |   |  ___  || |      (_____  )
| |      | (\ (      ) (         ) |   | |   | (   ) || |            ) |
| (____/\| ) \ \__   | |   /\____) |   | |   | )   ( || (____/\/\____) |
(_______/|/   \__/   \_/   \_______)   )_(   |/     \|(_______/\_______)   
    by chris and tony
    
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./CrystalsMetadata.sol";

interface IMANA {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address owner) external returns (uint256);
    function burn(uint256 amount) external;
    function ccMintTo(address recipient, uint256 amount) external;
}

/// @title Loot Crystals from the Rift
contract Crystals is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    ReentrancyGuard,
    Ownable
{
    using strings for string;
    using strings for strings.slice;

    address public metadataAddress;

    uint8 private constant cursedPrefixesLength = 8;
    uint8 private constant cursedSuffixesLength = 9;
    uint8 private constant prefixesLength = 9;
    uint8 private constant suffixesLength = 18;
    uint8 private constant colorsLength = 12;
    uint8 private constant specialColorsLength = 11;
    uint8 private constant slabsLength = 4;
    
    uint32 public maxLevel = 26;
    uint32 private constant MAX_CRYSTALS = 10000000;
    uint32 private constant RESERVED_OFFSET = MAX_CRYSTALS - 100000; // reserved for collabs

    struct Collab {
        address contractAddress;
        string namePrefix;
        uint256 levelBonus;
    }

    struct Crystal {
        bool minted;
        uint64 lastClaim;
        uint64 lastLevelUp;
        uint256 manaProduced;
        uint256 level;
        uint256 regNum;
    }

    struct Bag {
        uint64 generationsMinted;
    }

    uint256 public mintedCrystals;
    uint256 public registeredCrystals;

    uint256 public mintFee = 20000000000000000; //0.02 ETH
    uint256 public lootMintFee = 0;
    uint256 public mintLevel = 5;

    address public manaAddress;

    address public lootAddress = 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;
    address public mLootAddress = 0x1dfe7Ca09e99d10835Bf73044a23B73Fc20623DF;

    string private constant cursedPrefixes =
        "Dull,Broken,Twisted,Cracked,Fragmented,Splintered,Beaten,Ruined";
    string private constant cursedSuffixes =
        "of Rats,of Crypts,of Nightmares,of Sadness,of Darkness,of Death,of Doom,of Gloom,of Madness";
    string private constant prefixes =
        "Gleaming,Glowing,Shiny,Smooth,Faceted,Glassy,Polished,Sheeny,Luminous";
    string private constant suffixes =
        "of Power,of Giants,of Titans,of Skill,of Perfection,of Brilliance,of Enlightenment,of Protection,of Anger,of Rage,of Fury,of Vitriol,of the Fox,of Detection,of Reflection,of the Twins,of Relevance,of the Rift";
    string private constant colors =
        "Beige,Blue,Green,Red,Cyan,Yellow,Orange,Pink,Gray,White,Brown,Purple";
    string private constant specialColors =
        "Aqua,black,Crimson,Ghostwhite,Indigo,Turquoise,Maroon,Magenta,Fuchsia,Firebrick,Hotpink";
    string private constant slabs = "&#9698;,&#9699;,&#9700;,&#9701;";

    /// @dev indexed by bagId + (MAX_CRYSTALS * bag generation) == tokenId
    mapping(uint256 => Crystal) public crystals;

    /// @dev indexed by bagId
    mapping(uint256 => Bag) public bags;

    /// @notice 0 - 9 => collaboration nft contracts
    /// @notice 0 => Genesis Adventurer
    mapping(uint8 => Collab) public collabs;

    function setMetadataAddress(address addr) public onlyOwner {
        metadataAddress = addr;
    }

    modifier ownsCrystal(uint256 tokenId) {
        uint256 oSeed = tokenId % MAX_CRYSTALS;

        require(crystals[tokenId].level > 0, "UNREG");
        require(oSeed > 0, "TKN");
        require(tokenId <= (tokenId + (MAX_CRYSTALS * bags[tokenId].generationsMinted)), "INV");

        // checking minted crystal
        if (crystals[tokenId].minted == true) {
            require(ownerOf(tokenId) == _msgSender(), "UNAUTH");
        } else {
            isBagHolder(tokenId);
        }
        _;
    }

    modifier unminted(uint256 tokenId) {
        require(crystals[tokenId].minted == false, "MNTD");
        _;
    }

    constructor() ERC721("Loot Crystals", "CRYSTAL") Ownable() {}

    function claimableMana(uint256 tokenId) public view returns (uint256) {
        uint256 daysSinceClaim = diffDays(
            crystals[tokenId].lastClaim,
            block.timestamp
        );

        require(daysSinceClaim >= 1, "NONE");

        uint256 manaToProduce = daysSinceClaim * getResonance(tokenId);

        // amount generatable is capped to the crystals spin
        if (daysSinceClaim > crystals[tokenId].level) {
            manaToProduce = crystals[tokenId].level * getResonance(tokenId);
        }

        // if cap is hit, limit mana to cap or level, whichever is greater
        if ((manaToProduce + crystals[tokenId].manaProduced) > getSpin(tokenId)) {
            if (getSpin(tokenId) >= crystals[tokenId].manaProduced) {
                manaToProduce = getSpin(tokenId) - crystals[tokenId].manaProduced;
            } else {
                manaToProduce = 0;
            }

            if (manaToProduce < crystals[tokenId].level) {
                manaToProduce = crystals[tokenId].level;
            }
        }

        return manaToProduce;
    }

    function claimCrystalMana(uint256 tokenId) external ownsCrystal(tokenId) nonReentrant {
        uint256 manaToProduce = claimableMana(tokenId);
        crystals[tokenId].lastClaim = uint64(block.timestamp);
        crystals[tokenId].manaProduced += manaToProduce;
        IMANA(manaAddress).ccMintTo(_msgSender(), manaToProduce);
    }

    function levelUpCrystal(uint256 tokenId) external ownsCrystal(tokenId) nonReentrant {
        require(crystals[tokenId].level < maxLevel, "MAX");
        require(
            diffDays(
                crystals[tokenId].lastClaim,
                block.timestamp
            ) >= crystals[tokenId].level, "WAIT"
        );

        IMANA(manaAddress).ccMintTo(_msgSender(), crystals[tokenId].level);

        crystals[tokenId].level += 1;
        crystals[tokenId].lastClaim = uint64(block.timestamp);
        crystals[tokenId].lastLevelUp = uint64(block.timestamp);
        crystals[tokenId].manaProduced = 0;
    }

    function mintCrystal(uint256 tokenId)
        external
        payable
        unminted(tokenId)
        nonReentrant
    {
        require(tokenId > 0, "TKN");
        if (tokenId > 8000) {
            require(msg.value == mintFee, "FEE");
        } else {
            require(msg.value == lootMintFee, "FEE");
        }
        
        require(crystals[tokenId].level > 0, "UNREG");

        // can mint 1stGen immediately 
        if (bags[tokenId % MAX_CRYSTALS].generationsMinted != 0) {
            require(crystals[tokenId].level >= mintLevel, "LVL LOW");
        }

        isBagHolder(tokenId % MAX_CRYSTALS);        

        IMANA(manaAddress).ccMintTo(_msgSender(), isOGCrystal(tokenId) ? 100 : 10);

        crystals[tokenId].minted = true;

        // bag goes up a generation. owner can now register another crystal
        bags[tokenId % MAX_CRYSTALS].generationsMinted += 1;
        mintedCrystals += 1;
        _safeMint(_msgSender(), tokenId);
    }

    /// @notice registers a new crystal for a given bag
    /// @notice bag must not have a currently registered crystal
    function registerCrystal(uint256 bagId) external unminted(bagId + (MAX_CRYSTALS * bags[bagId].generationsMinted)) nonReentrant {
        require(bagId <= MAX_CRYSTALS, "INV");
        require(crystals[bagId + (MAX_CRYSTALS * bags[bagId].generationsMinted)].level == 0, "REG");

        isBagHolder(bagId);

        // set the source bag bagId
        crystals[bagId + (MAX_CRYSTALS * bags[bagId].generationsMinted)].level = 1;
        registeredCrystals += 1;
        crystals[bagId + (MAX_CRYSTALS * bags[bagId].generationsMinted)].regNum = registeredCrystals;
    }

    function registerCrystalCollab(uint256 tokenId, uint8 collabIndex) external nonReentrant {
        require(tokenId > 0 && tokenId < 10000, "TKN");
        require(collabIndex >= 0 && collabIndex < 10, "CLB");
        require(collabs[collabIndex].contractAddress != address(0), "CLB");
        uint256 collabToken = RESERVED_OFFSET + tokenId + (collabIndex * 10000);
        require(crystals[collabToken + (MAX_CRYSTALS * bags[collabToken].generationsMinted)].level == 0, "REG");

        require(
            ERC721(collabs[collabIndex].contractAddress).ownerOf(tokenId) == _msgSender(),
            "UNAUTH"
        );

        // only give bonus in first generation
        if (bags[collabToken].generationsMinted == 0) {
            crystals[collabToken + (MAX_CRYSTALS * bags[collabToken].generationsMinted)].level = collabs[collabIndex].levelBonus;
        } else {
            crystals[collabToken + (MAX_CRYSTALS * bags[collabToken].generationsMinted)].level = 1;
        }
    }

    /**
     * @dev Return the token URI through the Loot Expansion interface
     * @param lootId The Loot Character URI
     */
    function lootExpansionTokenUri(uint256 lootId) external view returns (string memory) {
        return tokenURI(lootId);
    }

    function ownerInit(
        address manaAddress_,
        address lootAddress_,
        address mLootAddress_
    ) external onlyOwner {
        require(manaAddress_ != address(0), "MANAADDR");
        manaAddress = manaAddress_;

        if (lootAddress_ != address(0)) {
            lootAddress = lootAddress_;
        }

        if (mLootAddress_ != address(0)) {
            mLootAddress = mLootAddress_;
        }
    }

    function ownerUpdateCollab(
        uint8 collabIndex,
        address contractAddress,
        uint16 levelBonus,
        string calldata namePrefix
    ) external onlyOwner {
        require(contractAddress != address(0), "ADDR");
        require(collabIndex >= 0 && collabIndex < 10, "CLB");
        require(
            collabs[collabIndex].contractAddress == contractAddress
                || collabs[collabIndex].contractAddress == address(0),
            "TAKEN"
        );
        collabs[collabIndex] = Collab(contractAddress, namePrefix, MAX_CRYSTALS * levelBonus);
    }

    function ownerUpdateMaxLevel(uint32 maxLevel_) external onlyOwner {
        require(maxLevel_ > maxLevel, "INV");
        maxLevel = maxLevel_;
    }

    function ownerSetMintFee(uint256 mintFee_) external onlyOwner {
        mintFee = mintFee_;
    }

    function ownerSetLootMintFee(uint256 lootMintFee_) external onlyOwner {
        lootMintFee = lootMintFee_;
    }

    function ownerWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function getColor(uint256 tokenId) public view returns (string memory) {
        if (getRoll(tokenId, "%CLR_RARITY", 20, 1) > 18) {
            return getItemFromCSV(
                specialColors,
                getRandom(tokenId, "%CLR") % specialColorsLength
            );
        }

        return getItemFromCSV(colors, getRandom(tokenId, "%CLR") % colorsLength);
    }

    function getLootType(uint256 tokenId) public view returns (string memory) {
        uint256 oSeed = tokenId % MAX_CRYSTALS;
        if (oSeed > 0 && oSeed < 8001) {
            return 'Loot';
        }

        if (oSeed > RESERVED_OFFSET) {
            return collabs[uint8((oSeed - RESERVED_OFFSET) / 10000)].namePrefix;
        }

        return 'mLoot';
    }

    function getName(uint256 tokenId) public view returns (string memory) {
        // check original seed to determine name type
        if ((tokenId % MAX_CRYSTALS) > 8000 && (tokenId % MAX_CRYSTALS) <= RESERVED_OFFSET) {
            return getBasicName(tokenId);
        }

        return getLootName(tokenId);
    }

    function getResonance(uint256 tokenId) public view returns (uint256) {
        return getLevelRolls(tokenId, "%RES", 2, 1) * (isOGCrystal(tokenId) ? 10 : 1) * (100 + (tokenId / MAX_CRYSTALS * 10)) / 100;
    }

    function getSpin(uint256 tokenId) public view returns (uint256) {
        uint256 multiplier = isOGCrystal(tokenId) ? 10 : 1;

        if (crystals[tokenId].level <= 1) {
            return (1 + getRoll(tokenId, "%SPIN", 20, 1)) * (100 + (tokenId / MAX_CRYSTALS * 10)) / 100;
        } else {
            return ((88 * (crystals[tokenId].level - 1)) + (getLevelRolls(tokenId, "%SPIN", 4, 1) * multiplier)) * (100 + (tokenId / MAX_CRYSTALS * 10)) / 100;
        }
    }

    function getRegisteredCrystal(uint256 bagId) public view returns (uint256) {
        return bags[bagId].generationsMinted * MAX_CRYSTALS + bagId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getSlabs(uint256 tokenId) private view returns (string memory output) {
        if (crystals[tokenId].level < 2) {
            return '';
        }

        output = '';

        uint256 rows = sqrt(crystals[tokenId].level - 1);

        for (uint256 i = 0; i < rows; i++) {
            output = string(
                abi.encodePacked(
                    output,
                    '<text class="slab" x="285" y="',
                    toString(295 + (19 * i)),
                    '">'
            ));

            for (uint256 j = 0; j < rows; j++) {
                output = string(abi.encodePacked(output, getSlab(tokenId, i, j)));
            }

            output = string(abi.encodePacked(output, '</text>'));
        }

        return output;
    }

     function tokenURI(uint256 tokenID) 
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory) 
    {
        require(metadataAddress != address(0), "no addr set");
        require(crystals[tokenID].level > 0, "INV");
        return ICrystalsMetadata(metadataAddress).tokenURI(tokenID, 
                                                        crystals[tokenID].level, 
                                                        (bags[tokenID % MAX_CRYSTALS].generationsMinted + 1), 
                                                        tokenID % MAX_CRYSTALS);
    }

    function diffDays(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256)
    {
        require(fromTimestamp <= toTimestamp);
        return (toTimestamp - fromTimestamp) / (24 * 60 * 60);
    }

    function getBasicName(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        uint256 rand = getRandom(tokenId, "%BSC_NAME");
        uint256 alignment = getRoll(tokenId, "%ALIGNMENT", 20, 1);

        string memory output = "Crystal";
        // set our surface type
        output = string(
            abi.encodePacked(
                getSurfaceType(tokenId),
                " ",
                output
            )
        );
        
        if (
            alignment == 10
            && getRoll(tokenId, "%CLR_RARITY", 20, 1) == 10
        ) {
            output = "Average Crystal";
        } else if (alignment == 20) {
            output = string(
                abi.encodePacked(
                    output,
                    " ",
                    getItemFromCSV(suffixes, rand % suffixesLength)
                )
            );
        } else if (alignment < 5) {
            output = string(
                abi.encodePacked(
                    output,
                    " ",
                    getItemFromCSV(cursedSuffixes, rand % cursedSuffixesLength)
                )
            );
        } else if (alignment > 15) {
            output = string(
                abi.encodePacked(
                    output,
                    " ",
                    getItemFromCSV(suffixes, rand % suffixesLength)
                )
            );
        } 

        return output;
    }

    function getLootName(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        uint256 rand = getRandom(tokenId, "%LOOT_NAME");
        uint256 alignment = getRoll(tokenId, "%ALIGNMENT", 20, 1);

        string memory output = "";
        string memory baseName = "Crystal";

        if (tokenId % MAX_CRYSTALS > RESERVED_OFFSET) {
            baseName = string(abi.encodePacked(
                collabs[uint8(((tokenId % MAX_CRYSTALS) - RESERVED_OFFSET) / 10000)].namePrefix,
                baseName
            ));
        }

        // set our surface type
        if (alignment < 9 || alignment > 11) {
            baseName = string(
                abi.encodePacked(
                    getSurfaceType(tokenId),
                    " ",
                    baseName
                )
            );
        }

        // average
        if (alignment == 10 && getRoll(tokenId, "%CLR_RARITY", 20, 1) == 10) {
            output = string(
                abi.encodePacked(
                    "Perfectly Average ",
                    baseName
                )
            );
        }
        // cursed
        else if (alignment < 5) {
            if (alignment == 1) {
                baseName = string(
                    abi.encodePacked(
                        "Demonic ",
                        baseName
                    )
                );
            }
            output = string(
                abi.encodePacked(
                    baseName,
                    " ",
                    getItemFromCSV(cursedSuffixes, rand % cursedSuffixesLength)
                )
            );
        }
        // standard
        else if (alignment < 16) {
            output = string(
                abi.encodePacked(
                    baseName
                )
            );
        }
        // good
        else if (alignment > 15 && alignment < 20) {
            output = string(
                abi.encodePacked(
                    baseName,
                    " ",
                    getItemFromCSV(suffixes, rand % suffixesLength)
                )
            );
        }
        // great
        else if (alignment == 20) {
            output = string(
                abi.encodePacked(
                    "Divine ",
                    baseName,
                    " ",
                    getItemFromCSV(suffixes, rand % suffixesLength)
                )
            );
        }

        return output;
    }

    function getSurfaceType(uint256 tokenId)
        internal
        view
        returns (string memory) 
    {
        uint256 rand = getRandom(tokenId, "%SURFACE_TYPE");
        uint256 alignment = getRoll(tokenId, "%ALIGNMENT", 20, 1);

        if (alignment < 9) {
            return getItemFromCSV(cursedPrefixes, rand % cursedPrefixesLength);
        } else if (alignment > 11) {
            return getItemFromCSV(prefixes, rand % prefixesLength);
        } else {
            return "Plain";
        }

    }

    function getItemFromCSV(string memory str, uint256 index)
        internal
        pure
        returns (string memory)
    {
        strings.slice memory strSlice = str.toSlice();
        string memory separatorStr = ",";
        strings.slice memory separator = separatorStr.toSlice();
        strings.slice memory item;
        for (uint256 i = 0; i <= index; i++) {
            item = strSlice.split(separator);
        }
        return item.toString();
    }
    function getLevelRolls(
        uint256 tokenId,
        string memory key,
        uint256 size,
        uint256 times
    ) internal view returns (uint256) {
        uint256 index = 1;
        uint256 score = getRoll(tokenId, key, size, times);
        uint256 level = crystals[tokenId].level;

        while (index < level) {
            score += ((
                random(string(abi.encodePacked(
                    (index * MAX_CRYSTALS) + tokenId,
                    key
                ))) % size
            ) + 1) * times;

            index++;
        }

        return score;
    }

    /// @dev returns random number based on the tokenId
    function getRandom(uint256 tokenId, string memory key)
        internal
        view
        returns (uint256)
    {
        return random(string(abi.encodePacked(tokenId, key, crystals[tokenId].regNum)));
    }

    /// @dev returns random roll based on the tokenId
    function getRoll(
        uint256 tokenId,
        string memory key,
        uint256 size,
        uint256 times
    ) internal view returns (uint256) {
        return ((getRandom(tokenId, key) % size) + 1) * times;
    }
    
    function getSlab(uint256 tokenId, uint256 x, uint256 y) internal view returns (string memory output) {
        output = getItemFromCSV(
                        slabs,
                        getRandom(
                            tokenId,
                            string(abi.encodePacked("SLAB_", toString(x), "_", toString(y)))
                        ) % slabsLength
                    );

        return output;
    }

    function isOGCrystal(uint256 tokenId) internal pure returns (bool) {
        // treat OG Loot and GA Crystals as OG
        return tokenId % MAX_CRYSTALS < 8001 || tokenId % MAX_CRYSTALS > RESERVED_OFFSET;
    }

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input, "%RIFT-OPEN")));
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

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function isBagHolder(uint256 tokenId) private view {
        uint256 oSeed = tokenId % MAX_CRYSTALS;
        if (oSeed < 8001) {
            require(ERC721(lootAddress).ownerOf(oSeed) == _msgSender(), "UNAUTH");
        } else if (oSeed <= RESERVED_OFFSET) {
            require(ERC721(mLootAddress).ownerOf(oSeed) == _msgSender(), "UNAUTH");
        } else {
            uint256 collabTokenId = tokenId % 10000;
            uint8 collabIndex = uint8((oSeed - RESERVED_OFFSET) / 10000);
            if (collabTokenId == 0) {
                collabTokenId = 10000;
                collabIndex -= 1;
            }
            require(collabIndex >= 0 && collabIndex < 10, "CLB");
            require(collabs[collabIndex].contractAddress != address(0), "NOADDR");
            require(
                ERC721(collabs[collabIndex].contractAddress)
                    .ownerOf(collabTokenId) == _msgSender(),
                "UNAUTH"
            );
        }
    }
}

/// @notice Calculates the square root of x, rounding down.
/// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
/// @param x The uint256 number for which to calculate the square root.
/// @return result The result as an uint256.
function sqrt(uint256 x) pure returns (uint256 result) {
    if (x == 0) {
        return 0;
    }

    // Calculate the square root of the perfect square of a power of two that is the closest to x.
    uint256 xAux = uint256(x);
    result = 1;
    if (xAux >= 0x100000000000000000000000000000000) {
        xAux >>= 128;
        result <<= 64;
    }
    if (xAux >= 0x10000000000000000) {
        xAux >>= 64;
        result <<= 32;
    }
    if (xAux >= 0x100000000) {
        xAux >>= 32;
        result <<= 16;
    }
    if (xAux >= 0x10000) {
        xAux >>= 16;
        result <<= 8;
    }
    if (xAux >= 0x100) {
        xAux >>= 8;
        result <<= 4;
    }
    if (xAux >= 0x10) {
        xAux >>= 4;
        result <<= 2;
    }
    if (xAux >= 0x8) {
        result <<= 1;
    }

    // The operations can never overflow because the result is max 2^127 when it enters this block.
    unchecked {
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1; // Seven iterations should be enough
        uint256 roundedDownResult = x / result;
        return result >= roundedDownResult ? roundedDownResult : result;
    }
}

library strings {
    struct slice {
        uint256 _len;
        uint256 _ptr;
    }

    function memcpy(
        uint256 dest,
        uint256 src,
        uint256 len
    ) private pure {
        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint256 mask = 256**(32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    function toSlice(string memory self) internal pure returns (slice memory) {
        uint256 ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }

    
    function toString(slice memory self) internal pure returns (string memory) {
        string memory ret = new string(self._len);
        uint256 retptr;
        assembly {
            retptr := add(ret, 32)
        }

        memcpy(retptr, self._ptr, self._len);
        return ret;
    }

    function findPtr(
        uint256 selflen,
        uint256 selfptr,
        uint256 needlelen,
        uint256 needleptr
    ) private pure returns (uint256) {
        uint256 ptr = selfptr;
        uint256 idx;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask = bytes32(~(2**(8 * (32 - needlelen)) - 1));

                bytes32 needledata;
                assembly {
                    needledata := and(mload(needleptr), mask)
                }

                uint256 end = selfptr + selflen - needlelen;
                bytes32 ptrdata;
                assembly {
                    ptrdata := and(mload(ptr), mask)
                }

                while (ptrdata != needledata) {
                    if (ptr >= end) return selfptr + selflen;
                    ptr++;
                    assembly {
                        ptrdata := and(mload(ptr), mask)
                    }
                }
                return ptr;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly {
                    hash := keccak256(needleptr, needlelen)
                }

                for (idx = 0; idx <= selflen - needlelen; idx++) {
                    bytes32 testHash;
                    assembly {
                        testHash := keccak256(ptr, needlelen)
                    }
                    if (hash == testHash) return ptr;
                    ptr += 1;
                }
            }
        }
        return selfptr + selflen;
    }

    function split(
        slice memory self,
        slice memory needle,
        slice memory token
    ) internal pure returns (slice memory) {
        uint256 ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = self._ptr;
        token._len = ptr - self._ptr;
        if (ptr == self._ptr + self._len) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
            self._ptr = ptr + needle._len;
        }
        return token;
    }

    function split(slice memory self, slice memory needle)
        internal
        pure
        returns (slice memory token)
    {
        split(self, needle, token);
    }
}
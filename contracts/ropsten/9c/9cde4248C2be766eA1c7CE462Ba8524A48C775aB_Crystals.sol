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

    uint8 private constant cursedPrefixesLength = 8;
    uint8 private constant cursedSuffixesLength = 9;
    uint8 private constant prefixesLength = 9;
    uint8 private constant suffixesLength = 18;
    uint8 private constant colorsLength = 12;
    uint8 private constant specialColorsLength = 11;
    uint8 private constant slabsLength = 4;
    
    uint32 public maxLevel = 20;
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
        uint256 tokenId;
    }

    uint256 public mintedCrystals;
    // uint256 public lootersPrice = 90000000000000000; //0.09 ETH
    uint256 public mintFee = 30000000000000000; //0.03 ETH
    uint256 public lootMintFee = 0;

    address public manaAddress;

    // https://etherscan.io/address/0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7
    address public lootAddress = 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;

    // https://etherscan.io/address/0x1dfe7Ca09e99d10835Bf73044a23B73Fc20623DF
    address public mLootAddress = 0x1dfe7Ca09e99d10835Bf73044a23B73Fc20623DF;

    // // https://etherscan.io/address/0x8dB687aCEb92c66f013e1D614137238Cc698fEdb
    // ERC721 public genesisAdventure =
    //     ERC721(0x8dB687aCEb92c66f013e1D614137238Cc698fEdb);

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

    /// @dev indexed by originalSeed (Loot/mLoot id)
    mapping(uint256 => Crystal) public crystals;

    /// @notice 0 - 9 => collaboration nft contracts
    /// @notice 0 => Genesis Adventurer https://etherscan.io/address/0x8dB687aCEb92c66f013e1D614137238Cc698fEdb
    mapping(uint8 => Collab) public collabs;

    modifier ownsCrystal(uint256 tokenId) {
        uint256 oSeed = tokenId % MAX_CRYSTALS;

        require(oSeed > 0, "TOKEN");
        require(tokenId <= crystals[oSeed].tokenId, "INVALID");

        if (crystals[oSeed].minted == true) {
            require(ownerOf(crystals[oSeed].tokenId) == _msgSender(), "UNAUTH");
        } else {
            isBagHolder(tokenId);
        }
        _;
    }

    modifier unminted(uint256 tokenId) {
        require(crystals[tokenId % MAX_CRYSTALS].minted == false, "MINTED");
        _;
    }

    constructor() ERC721("Loot Crystals", "CRYSTAL") Ownable() {}

    // TODO: REMOVE AFTER TESTING
    function testMint(uint256 tokenId) external unminted(tokenId) {
        IMANA(manaAddress).ccMintTo(_msgSender(), isOGCrystal(tokenId) ? 100 : 10);
        crystals[tokenId % MAX_CRYSTALS].tokenId = tokenId;
        crystals[tokenId % MAX_CRYSTALS].minted = true;
        mintedCrystals = mintedCrystals + 1;
        _safeMint(_msgSender(), tokenId);
    }
    
    // TODO: REMOVE AFTER TESTING
    function testRegister(uint256 tokenId) external unminted(tokenId) nonReentrant {
        crystals[tokenId].tokenId = tokenId;
    }

    /// @notice gain AMNA, can be used once a day
    /// @notice crystals can only generate a certain amount of AMNA every level
    /// @notice the amount generated is dependent on
    /// 1. the crystal's resonance
    /// 2. the number of days since AMNA was claimed from the crystal
    /// 3. how much mana has been claimed at the crystal's current level
    /// @notice crystal will charge every day if AMNA is not claimed
    /// @param tokenId crystal id, loot/mloot id or collab id + collab offset
    function claimCrystalMana(uint256 tokenId) external ownsCrystal(tokenId) nonReentrant {
        uint256 oSeed = tokenId % MAX_CRYSTALS;
        uint256 currentToken = crystals[oSeed].tokenId;

        uint256 daysSinceClaim = diffDays(
            crystals[oSeed].lastClaim,
            block.timestamp
        );

        require(daysSinceClaim >= 1, "WAIT");

        uint256 manaToProduce = daysSinceClaim * getResonance(currentToken);

        // amount generatable is capped to the crystals spin
        if (manaToProduce > getSpin(currentToken)) {
            manaToProduce = getSpin(currentToken);
        }

        // if cap is hit, limit mana to cap or level, whichever is greater
        if ((manaToProduce + crystals[oSeed].manaProduced) > getSpin(currentToken)) {
            if (getSpin(currentToken) >= crystals[oSeed].manaProduced) {
                manaToProduce = getSpin(currentToken) - crystals[oSeed].manaProduced;
            } else {
                manaToProduce = 0;
            }

            if (manaToProduce < getLevel(currentToken)) {
                manaToProduce = getLevel(currentToken);
            }
        }

        crystals[oSeed].lastClaim = uint64(block.timestamp);
        crystals[oSeed].manaProduced += manaToProduce;
        IMANA(manaAddress).ccMintTo(_msgSender(), manaToProduce);
    }

    /// @notice level up crystal, must have a fully charged crystal
    /// @notice gain AMNA equal to crystals level
    /// @param tokenId crystal id or loot/mloot id
    function levelUpCrystal(uint256 tokenId) external ownsCrystal(tokenId) nonReentrant {
        uint256 oSeed = tokenId % MAX_CRYSTALS;
        uint256 currentToken = crystals[oSeed].tokenId;

        require(getLevel(currentToken) < maxLevel, "MAX");
        require(
            diffDays(
                crystals[oSeed].lastClaim,
                block.timestamp
            ) >= getLevel(currentToken), "WAIT"
        );

        IMANA(manaAddress).ccMintTo(_msgSender(), getLevel(currentToken));

        if (crystals[oSeed].minted) {
            _burn(currentToken);
            _safeMint(_msgSender(), currentToken + MAX_CRYSTALS);
        }

        crystals[oSeed].tokenId = currentToken + MAX_CRYSTALS;
        crystals[oSeed].lastClaim = uint64(block.timestamp);
        crystals[oSeed].lastLevelUp = uint64(block.timestamp);
        crystals[oSeed].manaProduced = 0;
    }

    /// @notice mints crystal
    /// @param tokenId crystal id or loot/mloot id
    function mintCrystal(uint256 tokenId)
        external
        payable
        unminted(tokenId)
        nonReentrant
    {
        uint256 oSeed = tokenId % MAX_CRYSTALS;
        require(oSeed > 0, "TOKEN");
        if (oSeed > 8000) {
            require(msg.value == mintFee, "FEE");
        } else {
            require(msg.value == lootMintFee, "FEE");
        }

        uint256 tokenToMint = oSeed;

        isBagHolder(tokenId);
        if (crystals[tokenId].tokenId == 0) {
            // is unregistered
            if(oSeed > RESERVED_OFFSET) {
                tokenToMint =
                    oSeed + collabs[uint8((oSeed - RESERVED_OFFSET) / 10000)].levelBonus;
            }
        } else {
            // is registered
            tokenToMint = crystals[tokenId].tokenId;
        }

        IMANA(manaAddress).ccMintTo(_msgSender(), isOGCrystal(tokenId) ? 100 : 10);
        crystals[tokenId % MAX_CRYSTALS].tokenId = tokenId;
        crystals[tokenId % MAX_CRYSTALS].minted = true;
        mintedCrystals = mintedCrystals + 1;
        _safeMint(_msgSender(), tokenId);
    }

    function registerCrystal(uint256 tokenId) external unminted(tokenId) nonReentrant {
        require(crystals[tokenId].tokenId == 0, "REGISTERED");

        isBagHolder(tokenId);

        crystals[tokenId].tokenId = tokenId;
    }

    function registerCrystalCollab(uint256 tokenId, uint8 collabIndex) external nonReentrant {
        require(tokenId > 0 && tokenId < 10000, "TOKEN");
        require(collabIndex >= 0 && collabIndex < 10, "COLLAB");
        require(collabs[collabIndex].contractAddress != address(0), "COLLAB");
        uint256 collabToken = RESERVED_OFFSET + tokenId + (collabIndex * 10000);
        require(crystals[collabToken].tokenId == 0, "REG");

        require(
            ERC721(collabs[collabIndex].contractAddress).ownerOf(tokenId) == _msgSender(),
            "UNAUTH"
        );

        crystals[collabToken].tokenId = collabToken + collabs[collabIndex].levelBonus;
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
        require(contractAddress != address(0), "ADDRESS");
        require(collabIndex >= 0 && collabIndex < 10, "COLLAB");
        require(
            collabs[collabIndex].contractAddress == contractAddress
                || collabs[collabIndex].contractAddress == address(0),
            "TAKEN"
        );
        collabs[collabIndex] = Collab(contractAddress, namePrefix, MAX_CRYSTALS * levelBonus);
        // collabs[collabIndex].contractAddress = contractAddress;
        // collabs[collabIndex].levelBonus = MAX_CRYSTALS * levelBonus;
        // collabs[collabIndex].namePrefix = namePrefix;
    }

    function ownerUpdateMaxLevel(uint32 maxLevel_) external onlyOwner {
        require(maxLevel_ > maxLevel, "INVALID");
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

    function getColor(uint256 tokenId) public pure returns (string memory) {
        if (getRollOS(tokenId, "%COLOR_RARITY", 20, 1) > 18) {
            return getItemFromCSV(
                specialColors,
                getRandomOS(tokenId, "%COLOR") % specialColorsLength
            );
        }

        return getItemFromCSV(colors, getRandomOS(tokenId, "%COLOR") % colorsLength);
    }

    function getLevel(uint256 tokenId) public pure returns (uint256) {
        if (tokenId % MAX_CRYSTALS == tokenId) {
            return 1;
        }

        return (tokenId / MAX_CRYSTALS) + 1;
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
        uint256 oSeed = tokenId % MAX_CRYSTALS;

        if (oSeed > 8000 && oSeed <= RESERVED_OFFSET) {
            return getBasicName(oSeed);
        }

        return getLootName(oSeed);
        // return isFromLoot == 1 ? getLootName(oSeed) : getBasicName(oSeed);
        // return level > 1 ? string(abi.encodePacked(isFromLoot == 1 ? getLootName(oSeed) : getBasicName(oSeed), " +", level)) : isFromLoot == 1 ? getLootName(oSeed) : getBasicName(oSeed);
    }

    function getResonance(uint256 tokenId) public pure returns (uint256) {
        return getLevelRolls(tokenId, "%RESONANCE", 2, 1) * (isOGCrystal(tokenId) ? 10 : 1);
    }

    function getSpin(uint256 tokenId) public pure returns (uint256) {
        uint256 multiplier = isOGCrystal(tokenId) ? 10 : 1;

        if (getLevel(tokenId) == 1) {
            return 1 + getLevelRolls(tokenId, "%SPIN", 2, 1) * multiplier;
        } else {
            return 88 * (getLevel(tokenId) - 1) + getLevelRolls(tokenId, "%SPIN", 4, 1) * multiplier;
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        uint256 currentToken = crystals[tokenId % MAX_CRYSTALS].tokenId == 0
            ? tokenId : crystals[tokenId % MAX_CRYSTALS].tokenId;
        string memory output;

        string memory styles = string(
            abi.encodePacked(
                "<style>text{fill:",
                getColor(currentToken),
                ";font-family:serif;font-size:14px}.slab{transform:rotate(180deg)translate(75px, 79px);",
                "transform-origin:bottom right;font-size:22px;}</style>"
            )
        );

        output = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
                styles,
                '<rect width="100%" height="100%" fill="black" /><text x="10" y="20">',
                getName(currentToken),
                (
                    getLevel(currentToken) > 1
                        ? string(
                            abi.encodePacked(
                                " +",
                                toString(getLevel(currentToken) - 1)
                            )
                        )
                        : ""
                )
            )
        );

        output = string(
            abi.encodePacked(
                output,
                '</text><text x="10" y="40">',
                "Resonance: ",
                toString(getResonance(currentToken)),
                '</text>'
            )
        );
        output = string(
            abi.encodePacked(
                output,
                '<text x="10" y="60">',
                "Spin: ",
                toString(getSpin(currentToken)),
                '</text>'
            )
        );

        // ROW 1
        output = string(
            abi.encodePacked(
                output,
                slabRow(currentToken, 1, 295),
                slabRow(currentToken, 2, 314),
                slabRow(currentToken, 3, 333),
                slabRow(currentToken, 4, 352),
                slabRow(currentToken, 5, 371),
                slabRow(currentToken, 6, 390)
        ));

        output = string(
            abi.encodePacked(
                output,
                slabRow(currentToken, 7, 409),
                slabRow(currentToken, 8, 428),
                slabRow(currentToken, 9, 447),
                slabRow(currentToken, 10, 466),
                slabRow(currentToken, 11, 485),
                '</svg>'
        ));

        string memory attributes = string(
            abi.encodePacked(
                '"attributes": [ ',
                '{ "trait_type": "Level", "value": ', toString(getLevel(currentToken)), ' }, ',
                '{ "trait_type": "Resonance", "value": ', toString(getResonance(currentToken)), ' }, ',
                '{ "trait_type": "Spin", "value": ', toString(getSpin(currentToken)), ' }, '
        ));
        
        attributes = string(
            abi.encodePacked(
                attributes,
                '{ "trait_type": "Loot Type", "value": "', getLootType(currentToken), '" }, ',
                '{ "trait_type": "Surface", "value": ', getSurfaceType(currentToken), ' }, ',
                '{ "trait_type": "Color", "value": "', getColor(currentToken) ,'" } ]'
            )
        );

        string memory prefix = string(
            abi.encodePacked(
                '{"id": ', toString(currentToken), ', ',
                '"name": "', getName(currentToken), '", ',
                '"seedId": ', toString(currentToken % MAX_CRYSTALS), ', ',
                '"description": "This crystal vibrates with energy from the Rift!", ',
                '"background_color": "000000"'
        ));

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        prefix, ', ',
                        attributes, ', ',
                        '"image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
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
        pure
        returns (string memory)
    {
        uint256 rand = getRandomOS(tokenId, "%BASIC_NAME");
        uint256 alignment = getRollOS(tokenId, "%ALIGNMENT", 20, 1);

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
            && getRollOS(tokenId, "%COLOR_RARITY", 20, 1) == 10
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
        uint256 rand = getRandomOS(tokenId, "%LOOT_NAME");
        uint256 alignment = getRollOS(tokenId, "%ALIGNMENT", 20, 1);

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
        if (alignment == 10 && getRollOS(tokenId, "%COLOR_RARITY", 20, 1) == 10) {
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
        // shouldn't happen lol
        else {
            output = string(
                abi.encodePacked(
                    "Forgotten ",
                    baseName
                )
            );
        }

        return output;
        // return string(abi.encodePacked(toString(alignment), " - ", output));
    }

    function getSurfaceType(uint256 tokenId)
        internal
        pure
        returns (string memory) 
    {
        uint256 rand = getRandomOS(tokenId, "%SURFACE_TYPE");
        uint256 alignment = getRollOS(tokenId, "%ALIGNMENT", 20, 1);

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

    /// @notice makes a roll for each crystal level
    /// @param tokenId id of crystal
    /// @param key seed for randomization
    /// @param size size of dice
    /// @param times number of die
    function getLevelRolls(
        uint256 tokenId,
        string memory key,
        uint256 size,
        uint256 times
    ) internal pure returns (uint256) {
        uint256 index = 1;
        uint256 score = getRollOS(tokenId, key, size, times);
        uint256 level = getLevel(tokenId);

        while (index < level) {
            score += ((
                random(string(abi.encodePacked(
                    (index * MAX_CRYSTALS) + (tokenId % MAX_CRYSTALS),
                    key
                ))) % size
            ) + 1) * times;

            index++;
        }

        return score;
    }

    /// @dev returns random number based on the original seed (tokenId % MAX_CRYSTALS)
    function getRandomOS(uint256 tokenId, string memory key)
        internal
        pure
        returns (uint256)
    {
        return random(string(abi.encodePacked(tokenId % MAX_CRYSTALS, key)));
    }

    /// @dev returns random roll based on the original seed (tokenId % MAX_CRYSTALS)
    function getRollOS(
        uint256 tokenId,
        string memory key,
        uint256 size,
        uint256 times
    ) internal pure returns (uint256) {
        return ((getRandomOS(tokenId, key) % size) + 1) * times;
    }

    function isOGCrystal(uint256 tokenId) internal pure returns (bool) {
        // treat OG Loot and GA Crystals as OG
        return tokenId % MAX_CRYSTALS < 8001 || tokenId % MAX_CRYSTALS > RESERVED_OFFSET;
    }

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input, "%RIFT-OPEN")));
    }
    
    function slabRow(uint256 tokenId, uint256 row, uint256 y) internal pure returns (string memory output) {
        output = "";
        
        for (uint i = 1; i < 19; i++) {
            output = string(abi.encodePacked(
                output,
                (getLevel(tokenId) > 1 && i + ((row - 1) * 18) < getLevel(tokenId)) ?
                    getItemFromCSV(
                        slabs,
                        getRandomOS(
                            tokenId,
                            string(abi.encodePacked("SLAB_", toString(i + ((row - 1) * 18))))
                        ) % slabsLength
                    ) : " "
            ));
        }

        output = string(abi.encodePacked(
            '<text class="slab" x="285" y="', toString(y), '">',
            output,
            '</text>'
        ));

        return output;
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
            require(collabIndex >= 0 && collabIndex < 10, "COLLAB");
            require(collabs[collabIndex].contractAddress != address(0), "NOADDR");
            require(
                ERC721(collabs[collabIndex].contractAddress)
                    .ownerOf(collabTokenId) == _msgSender(),
                "UNAUTH"
            );
        }
    }
}


/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
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

    /*
     * @dev Returns a slice containing the entire string.
     * @param self The string to make a slice from.
     * @return A newly allocated slice containing the entire string.
     */
    function toSlice(string memory self) internal pure returns (slice memory) {
        uint256 ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }

    /*
     * @dev Copies a slice to a new string.
     * @param self The slice to copy.
     * @return A newly allocated string containing the slice's text.
     */
    function toString(slice memory self) internal pure returns (string memory) {
        string memory ret = new string(self._len);
        uint256 retptr;
        assembly {
            retptr := add(ret, 32)
        }

        memcpy(retptr, self._ptr, self._len);
        return ret;
    }

    // Returns the memory address of the first byte of the first occurrence of
    // `needle` in `self`, or the first byte after `self` if not found.
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

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and `token` to everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
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

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and returning everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and the entirety of `self` is returned.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` up to the first occurrence of `delim`.
     */
    function split(slice memory self, slice memory needle)
        internal
        pure
        returns (slice memory token)
    {
        split(self, needle, token);
    }
}
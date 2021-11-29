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
import "@openzeppelin/contracts/security/Pausable.sol";
import "./CrystalsMetadata.sol";
import "./CrystalManaCalculator.sol";
import "./ICrystals.sol";

interface IMANA {
    function ccMintTo(address recipient, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

/// @title Loot Crystals from the Rift
contract Crystals is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    ReentrancyGuard,
    Ownable,
    Pausable
{
    address public metadataAddress;
    address public manaCalculationAddress;
    
    uint32 public maxLevel = 26;
    uint32 private constant MAX_CRYSTALS = 10000000;
    uint32 private constant RESERVED_OFFSET = MAX_CRYSTALS - 100000; // reserved for collabs
    uint32 private mintedThreshold = 2;

    struct Bag {
        uint64 generationsMinted;
    }

    uint256 public mintedCrystals;
    uint256 public registeredCrystals;

    uint256 public mintFee = 0.02 ether;
    uint256 public mMintFee = 0.01 ether;

    // uint256 public lootMintFee = 0;
    // uint256 public mintLevel = 5;

    struct GenerationMintRequirement {
        uint256 manaCost;
    }

    address public manaAddress;

    address public lootAddress = 0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7;
    address public mLootAddress = 0x1dfe7Ca09e99d10835Bf73044a23B73Fc20623DF;

    /// @dev indexed by bagId + (MAX_CRYSTALS * bag generation) == tokenId
    mapping(uint256 => Crystal) public crystalsMap;

    /// @dev indexed by bagId
    mapping(uint256 => Bag) public bags;

    /// @notice 0 - 9 => collaboration nft contracts
    /// @notice 0 => Genesis Adventurer
    mapping(uint8 => Collab) public collabs;

    mapping(uint256 => GenerationMintRequirement) public genReq;

    mapping(uint64 => uint256) public generationRegistry;

    modifier unminted(uint256 tokenId) {
        require(crystalsMap[tokenId].minted == false, "MNTD");
        _;
    }

    constructor() ERC721("Loot Crystals", "CRYSTAL") Ownable() {}

    //WRITE

    function mintCrystal(uint256 tokenId)
        external
        payable
        whenNotPaused
        unminted(tokenId)
        nonReentrant
    {
        require(tokenId > 0, "TKN");
        require(crystalsMap[tokenId].level > 0, "UNREG");

        // mint fee is 100% MANA after registration threshold is reached
        if (mintedCrystals < mintedThreshold) {
            if (tokenId % MAX_CRYSTALS > 8000) {
                require(msg.value == (tokenId / MAX_CRYSTALS + 1) * mMintFee, "FEE");
            } else {
                require(msg.value == (tokenId / MAX_CRYSTALS + 1) * mintFee, "FEE");
            }   
        } else {
            require(msg.value == 0, "only mana");
            if (tokenId % MAX_CRYSTALS > 8000) {
                IMANA(manaAddress).burn(_msgSender(), (tokenId / MAX_CRYSTALS + 1) * 10);
            } else {
                IMANA(manaAddress).burn(_msgSender(), (tokenId / MAX_CRYSTALS + 1) * 100);
            }   
        }
        
        isBagHolder(tokenId % MAX_CRYSTALS);        

        crystalsMap[tokenId].minted = true;

        // bag goes up a generation. owner can now register another crystal
        bags[tokenId % MAX_CRYSTALS].generationsMinted += 1;
        mintedCrystals += 1;
        _safeMint(_msgSender(), tokenId);
    }

    /// @notice registers a new crystal for a given bag
    /// @notice bag must not have a currently registered crystal
    function registerCrystal(uint256 bagId) external whenNotPaused unminted(bagId + (MAX_CRYSTALS * bags[bagId].generationsMinted)) nonReentrant {
        require(bagId <= MAX_CRYSTALS, "INV");
        require(crystalsMap[bagId + (MAX_CRYSTALS * bags[bagId].generationsMinted)].level == 0, "REG");

        isBagHolder(bagId);

        uint256 cost = 0;
        if (bags[bagId].generationsMinted > 0) {
            require(genReq[bags[bagId].generationsMinted + 1].manaCost > 0, "GEN NOT AVL"); 
            cost = getRegistrationCost(bags[bagId].generationsMinted + 1);
            if (!isOGCrystal(bagId)) cost = cost / 10;
        }

        IMANA(manaAddress).burn(_msgSender(), cost);

        generationRegistry[bags[bagId].generationsMinted + 1] += 1;
        
        // set the source bag bagId
        crystalsMap[bagId + (MAX_CRYSTALS * bags[bagId].generationsMinted)].level = 1;
        registeredCrystals += 1;
        crystalsMap[bagId + (MAX_CRYSTALS * bags[bagId].generationsMinted)].regNum = registeredCrystals;
    }

    function registerCrystalCollab(uint256 tokenId, uint8 collabIndex) external nonReentrant {
        require(tokenId > 0 && tokenId < 10000, "TKN");
        require(collabIndex >= 0 && collabIndex < 10, "CLB");
        require(collabs[collabIndex].contractAddress != address(0), "CLB");
        uint256 collabToken = RESERVED_OFFSET + tokenId + (collabIndex * 10000);
        require(crystalsMap[collabToken + (MAX_CRYSTALS * bags[collabToken].generationsMinted)].level == 0, "REG");

        require(
            ERC721(collabs[collabIndex].contractAddress).ownerOf(tokenId) == _msgSender(),
            "UNAUTH"
        );

        uint256 cost = 0;
        if (bags[collabToken].generationsMinted > 0) {
            require(genReq[bags[collabToken].generationsMinted + 1].manaCost > 0, "GEN NOT AVL"); 
            cost = getRegistrationCost(bags[collabToken].generationsMinted + 1);
            if (!isOGCrystal(collabToken)) cost = cost / 10;
        }

        IMANA(manaAddress).burn(_msgSender(), cost);

        generationRegistry[bags[collabToken].generationsMinted + 1] += 1;

        // only give bonus in first generation
        if (bags[collabToken].generationsMinted == 0) {
            crystalsMap[collabToken + (MAX_CRYSTALS * bags[collabToken].generationsMinted)].level = uint64(collabs[collabIndex].levelBonus);
        } else {
            crystalsMap[collabToken + (MAX_CRYSTALS * bags[collabToken].generationsMinted)].level = 1;
        }
    }

    function claimCrystalMana(uint256 tokenId) external whenNotPaused ownsCrystal(tokenId) nonReentrant {
        uint256 manaToProduce = ICrystalManaCalculator(manaCalculationAddress).claimableMana(tokenId);
        crystalsMap[tokenId].lastClaim = uint64(block.timestamp);
        crystalsMap[tokenId].manaProduced += manaToProduce;
        IMANA(manaAddress).ccMintTo(_msgSender(), manaToProduce);
    }

    function levelUpCrystal(uint256 tokenId) external whenNotPaused ownsCrystal(tokenId) nonReentrant {
        require(crystalsMap[tokenId].level < maxLevel, "MAX");
        require(
            diffDays(
                crystalsMap[tokenId].lastClaim,
                block.timestamp
            ) >= crystalsMap[tokenId].level, "WAIT"
        );

        if (ICrystalManaCalculator(manaCalculationAddress).claimableMana(tokenId) > (crystalsMap[tokenId].level * getResonance(tokenId))) {
            IMANA(manaAddress).ccMintTo(_msgSender(), ICrystalManaCalculator(manaCalculationAddress).claimableMana(tokenId) - (crystalsMap[tokenId].level * getResonance(tokenId)));
        } 

        crystalsMap[tokenId].level += 1;
        crystalsMap[tokenId].lastClaim = uint64(block.timestamp);
        crystalsMap[tokenId].lastLevelUp = uint64(block.timestamp);
        crystalsMap[tokenId].manaProduced = 0;
    }

    // READ 
    function getResonance(uint256 tokenId) public view returns (uint256) {
        // 1 or 2 per level                             loot vs mloot multiplier               generation bonus
        return getLevelRolls(tokenId, "%RES", 2, 1) * (isOGCrystal(tokenId) ? 10 : 1) * generationBonus(tokenId / MAX_CRYSTALS);
    }

    // 10% increase per generation
    function generationBonus(uint256 genNum) internal pure returns (uint256) {
        // first gen
        if (genNum == 0) {
            return 1;
        } else {
            return (generationBonus(genNum - 1) * 110) / 100;
        }
    }

    function getSpin(uint256 tokenId) public view returns (uint256) {
        uint256 multiplier = isOGCrystal(tokenId) ? 10 : 1;
        return ((88 * (crystalsMap[tokenId].level)) + (getLevelRolls(tokenId, "%SPIN", 4, 1) * multiplier)) * generationBonus(tokenId / MAX_CRYSTALS);
    }

    function getRegistrationCost(uint64 genNum) public view returns (uint256) {
        uint256 cost = genReq[genNum].manaCost - generationRegistry[genNum];
        return cost < (genReq[genNum].manaCost / 10) ? (genReq[genNum].manaCost / 10) : cost;
    }

    function claimableMana(uint256 tokenId) public view returns (uint256) {
        return ICrystalManaCalculator(manaCalculationAddress).claimableMana(tokenId);
    }

    /**
     * @dev Return the token URI through the Loot Expansion interface
     * @param lootId The Loot Character URI
     */
    function getLootExpansionTokenUri(uint256 lootId) external view returns (string memory) {
        return tokenURI(lootId);
    }

    function getRegisteredCrystal(uint256 bagId) public view returns (uint256) {
        return bags[bagId].generationsMinted * MAX_CRYSTALS + bagId;
    }

    function generationsMinted(uint256 tokenId) public view returns (uint256) {
        return bags[tokenId % MAX_CRYSTALS].generationsMinted;
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
        require(metadataAddress != address(0), "no addr set");
        return ICrystalsMetadata(metadataAddress).tokenURI(tokenId);
    }

    // OWNER 

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

    function ownerSetGenMintRequirement(uint256 generation, uint256 manaCost_) external onlyOwner {
        genReq[generation].manaCost = manaCost_;
    }

    function ownerWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function ownerSetMetadataAddress(address addr) external onlyOwner {
        metadataAddress = addr;
    }

    function ownerSetMintedThreshold(uint32 threshold_) external onlyOwner {
        mintedThreshold = threshold_;
    }

    function ownerSetCalculatorAddress(address _calculatorAddress) external onlyOwner {
        manaCalculationAddress = _calculatorAddress;
    }

    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    // HELPER

    modifier ownsCrystal(uint256 tokenId) {
        uint256 oSeed = tokenId % MAX_CRYSTALS;

        require(crystalsMap[tokenId].level > 0, "UNREG");
        require(oSeed > 0, "TKN");
        require(tokenId <= (tokenId + (MAX_CRYSTALS * bags[tokenId].generationsMinted)), "INV");

        // checking minted crystal
        if (crystalsMap[tokenId].minted == true) {
            require(ownerOf(tokenId) == _msgSender(), "UNAUTH");
        } else {
            isBagHolder(tokenId);
        }
        _;
    }

    function isOGCrystal(uint256 tokenId) internal pure returns (bool) {
        // treat OG Loot and GA Crystals as OG
        return tokenId % MAX_CRYSTALS < 8001 || tokenId % MAX_CRYSTALS > RESERVED_OFFSET;
    }

    function diffDays(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256)
    {
        require(fromTimestamp <= toTimestamp);
        return (toTimestamp - fromTimestamp) / (24 * 60 * 60);
    }

    function getLevelRolls(
        uint256 tokenId,
        string memory key,
        uint256 size,
        uint256 times
    ) internal view returns (uint256) {
        uint256 index = 1;
        uint256 score = getRoll(tokenId, key, size, times);
        uint256 level = crystalsMap[tokenId].level;

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
        return random(string(abi.encodePacked(tokenId, key, crystalsMap[tokenId].regNum)));
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
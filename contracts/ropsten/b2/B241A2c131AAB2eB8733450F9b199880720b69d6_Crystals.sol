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

import "./Interfaces.sol";
import "./IRift.sol";

/// @title Loot Crystals from the Rift
contract Crystals is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    ReentrancyGuard,
    Ownable,
    Pausable,
    IRiftBurnable
{
    struct GenerationMintRequirement {
        uint256 manaCost;
    }

    event ManaClaimed(address owner, uint256 tokenId, uint256 amount);
    event CrystalLeveled(address owner, uint256 tokenId, uint256 level);

    ICrystalsMetadata public iMetadata;
    ICrystalManaCalculator public iCalculator;

    IMana public iMana;
    IRift public iRift;

    ERC721 public iLoot = ERC721(0xFF9C1b15B16263C61d017ee9F65C50e4AE0113D7);
    ERC721 public iMLoot = ERC721(0x1dfe7Ca09e99d10835Bf73044a23B73Fc20623DF);
    
    uint32 public maxLevel = 26;
    uint32 private constant MAX_CRYSTALS = 10000000;
    uint32 private constant RESERVED_OFFSET = MAX_CRYSTALS - 100000; // reserved for collabs
    uint32 private mintedThreshold = 8000;

    uint256 public mintedCrystals;

    uint256 public mintFee = 0.02 ether;
    uint256 public mMintFee = 0.01 ether;

    // uint256 public lootMintFee = 0;
    // uint256 public mintLevel = 5;

    /// @dev indexed by bagId + (MAX_CRYSTALS * bag generation) == tokenId
    mapping(uint256 => Crystal) public crystalsMap;
    mapping(uint256 => Bag) public bags;

    /// @notice 0 - 9 => collaboration nft contracts
    /// @notice 0 => Genesis Adventurer
    mapping(uint8 => Collab) public collabs;

    constructor(address manaAddress) ERC721("Loot Crystals", "CRYSTAL") Ownable() {
        iMana = IMana(manaAddress);
    }

    //WRITE

    function mintCrystal(uint256 bagId)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        uint16 bagLevel = iRift.bags(bagId).level;

        // mint fee is 100% MANA after minted threshold is reached
        if (mintedCrystals < mintedThreshold) {
            if (bagId > 8000) {
                require(msg.value == bagLevel * mMintFee, "FEE");
            } else {
                require(msg.value == bagLevel * mintFee, "FEE");
            }   
        } else {
            require(msg.value == 0, "only mana");
            if (bagId > 8000) {
                iMana.burn(_msgSender(), bagLevel * 10);
            } else {
                iMana.burn(_msgSender(), bagLevel * 100);
            }   
        }

        iRift.useCharge(1, bagId, _msgSender());

        uint256 tokenId = getNextCrystal(bagId);

        bags[tokenId % MAX_CRYSTALS].mintCount += 1;
        crystalsMap[tokenId].attunement = bagLevel;
        crystalsMap[tokenId].level = 1;

        mintedCrystals += 1;
        _safeMint(_msgSender(), tokenId);
    }

    function claimCrystalMana(uint256 tokenId)
        external
        whenNotPaused
        ownsCrystal(tokenId)
        nonReentrant
    {
        uint256 manaToProduce = iCalculator.claimableMana(tokenId);
        require(manaToProduce > 0, "NONE");
        crystalsMap[tokenId].lastClaim = uint64(block.timestamp);
        crystalsMap[tokenId].levelManaProduced += manaToProduce;
        bags[tokenId % MAX_CRYSTALS].totalManaProduced += manaToProduce;
        iMana.ccMintTo(_msgSender(), manaToProduce);
        emit ManaClaimed(_msgSender(), tokenId, manaToProduce);
    }

    function levelUpCrystal(uint256 tokenId)
        external
        whenNotPaused
        ownsCrystal(tokenId)
        nonReentrant
    {
        Crystal memory crystal = crystalsMap[tokenId];
        require(crystal.level < maxLevel, "MAX");
        require(
            diffDays(
                crystal.lastClaim,
                block.timestamp
            ) >= crystal.level, "WAIT"
        );
        uint256 claimableMana = iCalculator.claimableMana(tokenId);
        if (claimableMana > (crystal.level * getResonance(tokenId))) {
            iMana.ccMintTo(_msgSender(), claimableMana - (crystal.level * getResonance(tokenId)));
        }

        crystalsMap[tokenId] = Crystal({
            level: crystal.level + 1,
            lastClaim: uint64(block.timestamp),
            lastLevelUp: uint64(block.timestamp),
            levelManaProduced: 0,
            attunement: crystal.attunement,
            regNum: crystal.regNum
        });

        emit CrystalLeveled(_msgSender(), tokenId, crystal.level);
    }

    // READ 
    function getResonance(uint256 tokenId) public view returns (uint256) {
        // 1 or 2 per level                             loot vs mloot multiplier               generation bonus
        return getLevelRolls(tokenId, "%RES", 2, 1)
            * (isOGCrystal(tokenId) ? 10 : 1)
            * attunementBonus(crystalsMap[tokenId].attunement);
    }

    // 10% increase per generation
    function attunementBonus(uint256 genNum) internal pure returns (uint256) {
        // first gen
        if (genNum == 0) {
            return 1;
        } else {
            return (attunementBonus(genNum - 1) * 110) / 100;
        }
    }

    function getSpin(uint256 tokenId) public view returns (uint256) {
        uint256 multiplier = isOGCrystal(tokenId) ? 10 : 1;
        return ((88 * (crystalsMap[tokenId].level))
            + (getLevelRolls(tokenId, "%SPIN", 4, 1) * multiplier))
            * attunementBonus(crystalsMap[tokenId].attunement);
    }

    function riftPower(uint256 tokenId) public view override returns (uint256) {
        return crystalsMap[tokenId].level * crystalsMap[tokenId].attunement / 2;
    }

    /**
     * @dev Return the token URI through the Loot Expansion interface
     * @param lootId The Loot Character URI
     */
    function getLootExpansionTokenUri(uint256 lootId) external view returns (string memory) {
        return tokenURI(lootId);
    }

    function getNextCrystal(uint256 bagId) public view returns (uint256) {
        return bags[bagId].mintCount * MAX_CRYSTALS + bagId;
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
        require(address(iMetadata) != address(0), "no addr set");
        return iMetadata.tokenURI(tokenId);
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

    // function ownerSetGenMintRequirement(uint256 generation, uint256 manaCost_) external onlyOwner {
    //     genReq[generation].manaCost = manaCost_;
    // }

    function ownerSetCalculatorAddress(address addr) external onlyOwner {
        iCalculator = ICrystalManaCalculator(addr);
    }

    function ownerSetRiftAddress(address addr) external onlyOwner {
        iRift = IRift(addr);
    }

    function ownerSetLootAddress(address addr) external onlyOwner {
        iLoot = ERC721(addr);
    }

    function ownerSetManaAddress(address addr) external onlyOwner {
        iMana = IMana(addr);
    }

    function ownerSetMLootAddress(address addr) external onlyOwner {
        iMLoot = ERC721(addr);
    }

    function ownerSetMetadataAddress(address addr) external onlyOwner {
        iMetadata = ICrystalsMetadata(addr);
    }

    function ownerSetMintedThreshold(uint32 threshold_) external onlyOwner {
        mintedThreshold = threshold_;
    }

    function ownerWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    // HELPER

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

    modifier ownsCrystal(uint256 tokenId) {
        require(ownerOf(tokenId) == _msgSender(), "UNAUTH");
        _;
    }
}
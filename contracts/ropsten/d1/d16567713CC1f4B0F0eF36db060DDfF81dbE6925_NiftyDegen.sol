// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./NameableCharacter.sol";
import "./AllowedColorsStorage.sol";

import "hardhat/console.sol";

/**
 * @title NiftyDegen NFT (The OG NFTs of the Nifty League on Ethereum)
 * @dev Extends NameableCharacter and NiftyLeagueCharacter (ERC721)
 */
contract NiftyDegen is NameableCharacter {
    using Counters for Counters.Counter;

    /// @notice Counter for number of minted characters
    Counters.Counter public totalSupply;

    /// @notice Max number of mintable characters
    uint256 public constant MAX_SUPPLY = 10000;

    /// @notice Special characters reserved for future giveaways
    uint256 public constant SPECIAL_CHARACTERS = 100;

    /// @dev Available traits storage address
    address internal immutable _storageAddress;

    /// @dev Mapping trait indexes to pool size of available traits
    mapping(uint256 => uint256) internal _originalPoolSizes;

    /// @dev Set if we want to override semi-fomo ramp pricing
    uint256 private _manualMintPrice;

    /**
     * @notice Construct the Nifty League NFTs
     * @param nftlAddress Address of verified Nifty League NFTL contract
     * @param storageAddress Address of verified Allowed Colors Storage
     */
    constructor(address nftlAddress, address storageAddress) NiftyLeagueCharacter(nftlAddress, "NiftyDegen", "DEGEN") {
        _storageAddress = storageAddress;
    }

    // External functions

    /**
     * @notice Validate character traits and purchase a Nifty Degen NFT
     * @param character Indexed list of character traits
     * @param head Indexed list of head traits
     * @param clothing Indexed list of clothing options
     * @param accessories Indexed list of accessories
     * @param items Indexed list of items
     * @dev Order is based on character selector indexes
     */
    function purchase(
        uint256[5] memory character,
        uint256[3] memory head,
        uint256[6] memory clothing,
        uint256[6] memory accessories,
        uint256[2] memory items
    ) external payable {
        uint256 currentSupply = totalSupply.current();
        require(currentSupply >= 3 || _msgSender() == owner(), "Sale has not started");
        require(!paused(), "Purchases are paused");
        require(msg.value == getNFTPrice(), "Ether value incorrect");
        _validateTraits(character, head, clothing, accessories, items);
        uint256 traitCombo = _generateTraitCombo(character, head, clothing, accessories, items);
        _storeNewCharacter(traitCombo);
    }

    /**
     * @notice Set pool size for each trait index called on deploy
     */
    function initPoolSizes() external onlyOwner {
        _originalPoolSizes[1] = 60;
        _originalPoolSizes[2] = 31;
        _originalPoolSizes[3] = 9;
        _originalPoolSizes[4] = 9;
        _originalPoolSizes[5] = 113;
        _originalPoolSizes[6] = 14;
        _originalPoolSizes[7] = 63;
        _originalPoolSizes[8] = 99;
        _originalPoolSizes[9] = 76;
        _originalPoolSizes[10] = 41;
        _originalPoolSizes[11] = 101;
        _originalPoolSizes[12] = 37;
        _originalPoolSizes[13] = 12;
        _originalPoolSizes[14] = 43;
        _originalPoolSizes[15] = 50;
        _originalPoolSizes[16] = 10;
        _originalPoolSizes[17] = 12;
        _originalPoolSizes[18] = 25;
        _originalPoolSizes[19] = 37;
        _originalPoolSizes[20] = 92;
        _originalPoolSizes[21] = 48;
    }

    /**
     * @notice Fallback to set NFT price to static ether value if necessary
     * @param newPrice New price to set for remaining character sale
     * @dev Minimum value of 0.08 ETH for this to be considered in getNFTPrice
     */
    function overrideMintPrice(uint256 newPrice) external onlyOwner {
        _manualMintPrice = newPrice;
    }

    // Public functions

    /**
     * @notice Gets current NFT Price based on current supply
     * @return Current price to mint 1 NFT
     */
    function getNFTPrice() public view returns (uint256) {
        uint256 currentSupply = totalSupply.current();
        require(
            currentSupply < MAX_SUPPLY - SPECIAL_CHARACTERS || (_msgSender() == owner() && currentSupply < MAX_SUPPLY),
            "Sale has already ended"
        );
        // 1 - 3 free for core team members, 9001 - 10000 free special community giveaway characters
        if (currentSupply < 3 || currentSupply >= 9900) return 0;
        // fallback option to override price floors only if necessary. Minimum value of 0.08 ETH
        if (_manualMintPrice >= 80000000000000000) return _manualMintPrice;
        if (currentSupply >= 9500) return 400000000000000000; // 9500 - 9900 0.4 ETH
        if (currentSupply >= 8500) return 340000000000000000; // 8501 - 9500 0.34 ETH
        if (currentSupply >= 6500) return 280000000000000000; // 6501 - 8500 0.28 ETH
        if (currentSupply >= 4500) return 220000000000000000; // 4501 - 6500 0.22 ETH
        if (currentSupply >= 2500) return 160000000000000000; // 2501 - 4500 0.16 ETH
        if (currentSupply >= 1000) return 120000000000000000; // 1001 - 2500 0.12 ETH
        return 80000000000000000; // 6 - 1000 0.08 ETH
    }

    /**
     * @notice Check if traits is allowed for tribe and hasn't been removed yet
     * @param tribe Tribe ID
     * @param trait Trait ID
     * @dev Trait types are restricted per tribe before deploy in AllowedColorsStorage
     * @return True if trait is available and allowed for tribe
     */
    function isAvailableAndAllowedTrait(uint256 tribe, uint256 trait) public view returns (bool) {
        if (trait == EMPTY_TRAIT) return true;
        if (trait >= 150) return isAvailableTrait(trait);
        AllowedColorsStorage colorsStorage = AllowedColorsStorage(_storageAddress);
        return isAvailableTrait(trait) && colorsStorage.isAllowedColor(tribe, trait);
    }

    // Internal functions

    /**
     * @notice Base URI for computing {tokenURI}. Overrides ERC721 default
     * @return Base token URI linked to IPFS metadata
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return "https://nifty-league.com/ipfs/metadata/degens";
    }

    // Private functions

    /**
     * @notice Validate character traits
     * @param char Indexed list of character traits
     * @param head Indexed list of head traits
     * @param cloth Indexed list of clothing options
     * @param acc Indexed list of accessories
     * @param items Indexed list of items
     */
    function _validateTraits(
        uint256[5] memory char,
        uint256[3] memory head,
        uint256[6] memory cloth,
        uint256[6] memory acc,
        uint256[2] memory items
    ) private view {
        uint256 tribe = char[0];
        require(tribe > 0 && (tribe <= 6 || (tribe <= 9 && _msgSender() == owner())), "Tribe incorrect");
        require(_isTraitInRange(char[1], 10, 69) || _isTraitInRange(char[1], 119, 149), "Skin color incorrect");
        require(_isTraitInRange(char[2], 70, 100) || _isTraitInRange(char[2], 119, 149), "Fur color incorrect");
        require(_isTraitInRange(char[3], 101, 109) || _isTraitInRange(char[3], 119, 149), "Eye color incorrect");
        require(_isTraitInRange(char[4], 110, 118) || _isTraitInRange(char[4], 119, 149), "Pupil color incorrect");
        require(_isTraitInRange(head[0], 150, 262), "Hair incorrect");
        require(_isTraitInRange(head[1], 263, 276), "Mouth incorrect");
        require(_isTraitInRange(head[2], 277, 339), "Beard incorrect");
        require(_isTraitInRange(cloth[0], 340, 438), "Top incorrect");
        require(_isTraitInRange(cloth[1], 439, 514), "Outerwear incorrect");
        require(_isTraitInRange(cloth[2], 515, 555), "Print incorrect");
        require(_isTraitInRange(cloth[3], 556, 657), "Bottom incorrect");
        require(_isTraitInRange(cloth[4], 658, 694), "Footwear incorrect");
        require(_isTraitInRange(cloth[5], 695, 706), "Belt incorrect");
        require(_isTraitInRange(acc[0], 707, 749), "Hat incorrect");
        require(_isTraitInRange(acc[1], 750, 799), "Eyewear incorrect");
        require(_isTraitInRange(acc[2], 800, 809), "Piercing incorrect");
        require(_isTraitInRange(acc[3], 810, 821), "Wist accessory incorrect");
        require(_isTraitInRange(acc[4], 822, 846), "Hands accessory incorrect");
        require(_isTraitInRange(acc[5], 847, 883), "Neckwear incorrect");
        require(_isTraitInRange(items[0], 884, 975), "Left item incorrect");
        require(_isTraitInRange(items[1], 976, 1023), "Right item incorrect");

        require(isAvailableAndAllowedTrait(tribe, char[1]), "Skin color unavailable");
        require(isAvailableAndAllowedTrait(tribe, char[2]), "Fur color unavailable");
        require(isAvailableAndAllowedTrait(tribe, char[3]), "Eye color unavailable");
        require(isAvailableAndAllowedTrait(tribe, char[4]), "Pupil color unavailable");
        require(isAvailableAndAllowedTrait(tribe, head[0]), "Hair unavailable");
        require(isAvailableAndAllowedTrait(tribe, head[1]), "Mouth unavailable");
        require(isAvailableAndAllowedTrait(tribe, head[2]), "Beard unavailable");
        require(isAvailableAndAllowedTrait(tribe, cloth[0]), "Top unavailable");
        require(isAvailableAndAllowedTrait(tribe, cloth[1]), "Outerwear unavailable");
        require(isAvailableAndAllowedTrait(tribe, cloth[2]), "Print unavailable");
        require(isAvailableAndAllowedTrait(tribe, cloth[3]), "Bottom unavailable");
        require(isAvailableAndAllowedTrait(tribe, cloth[4]), "Footwear unavailable");
        require(isAvailableAndAllowedTrait(tribe, cloth[5]), "Belt unavailable");
        require(isAvailableAndAllowedTrait(tribe, acc[0]), "Hat unavailable");
        require(isAvailableAndAllowedTrait(tribe, acc[1]), "Eyewear unavailable");
        require(isAvailableAndAllowedTrait(tribe, acc[2]), "Piercing unavailable");
        require(isAvailableAndAllowedTrait(tribe, acc[3]), "Wrist accessory unavailable");
        require(isAvailableAndAllowedTrait(tribe, acc[4]), "Hand accessory unavailable");
        require(isAvailableAndAllowedTrait(tribe, acc[5]), "Neckwear unavailable");
        require(isAvailableAndAllowedTrait(tribe, items[0]), "Left item unavailable");
        require(isAvailableAndAllowedTrait(tribe, items[1]), "Right item unavailable");
    }

    /**
     * @notice Mints NFT if unique and attempts to remove a random trait
     * @param traitCombo Trait combo provided from _generateTraitCombo
     */
    function _storeNewCharacter(uint256 traitCombo) private {
        require(isUnique(traitCombo), "NFT trait combo already exists");
        _existMap[traitCombo] = true;
        totalSupply.increment();
        uint256 newCharId = totalSupply.current();
        Character memory newChar;
        newChar.traits = traitCombo;
        _characters[newCharId] = newChar;
        _removeRandomTrait(newCharId, traitCombo);
        _safeMint(_msgSender(), newCharId);
    }

    /**
     * @notice Attempts to remove a random trait from availability
     * @param newCharId ID of newly generated NFT
     * @param traitCombo Trait combo provided from _generateTraitCombo
     * @dev Any trait id besides 0 or tribe ids can be removed
     */
    function _removeRandomTrait(uint256 newCharId, uint256 traitCombo) private {
        if (
            (removedTraits.length < 200 && newCharId % 4 == 0) ||
            (removedTraits.length < 400 && newCharId % 6 == 0) ||
            (removedTraits.length < 600 && newCharId % 8 == 0) ||
            (removedTraits.length < 800 && newCharId % 10 == 0)
        ) {
            uint256 randomIndex = _rngIndex(newCharId);
            uint16 randomTrait = _unpackUint10(traitCombo >> (randomIndex * 10));
            // Base character colors cannot be removed
            if (
                randomTrait != 0 &&
                randomTrait != 10 &&
                randomTrait != 22 &&
                randomTrait != 29 &&
                randomTrait != 37 &&
                randomTrait != 48 &&
                randomTrait != 59 &&
                randomTrait != 70 &&
                randomTrait != 82 &&
                randomTrait != 90 &&
                randomTrait != 101 &&
                randomTrait != 110
            ) {
                uint256 poolSize = _originalPoolSizes[randomIndex];
                bool skip = _rngSkip(poolSize);
                if (!skip) {
                    removedTraits.push(randomTrait);
                    _removedTraitsMap[randomTrait] = true;
                }
            }
        }
    }

    /**
     * @notice Simulate randomness for token index to attempt to remove
     * @param tokenId ID of newly generated NFT
     * @dev Randomness can be anticipated and exploited but is not crucial to NFT sale
     * @return Number from 1-21
     */
    function _rngIndex(uint256 tokenId) private view returns (uint256) {
        uint256 randomHash = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp, block.difficulty)));
        return (randomHash % 21) + 1;
    }

    /**
     * @notice Simulate randomness to decide to skip removing trait based on pool size
     * @param poolSize Number of trait options for a specific trait type
     * @dev Randomness can be anticipated and exploited but is not crucial to NFT sale
     * @return True if should skip this trait removal
     */
    function _rngSkip(uint256 poolSize) private view returns (bool) {
        uint256 randomHash = uint256(keccak256(abi.encodePacked(poolSize, block.timestamp, block.difficulty)));
        int256 odds = 13 - int256(randomHash % 26);
        return odds < int256(100 / poolSize);
    }

    /**
     * @notice Checks whether trait id is in range of lower/upper bounds
     * @param lower lower range-bound
     * @param upper upper range-bound
     * @return True if in range
     */
    function _isTraitInRange(
        uint256 trait,
        uint256 lower,
        uint256 upper
    ) private pure returns (bool) {
        return trait == EMPTY_TRAIT || (trait >= lower && trait <= upper);
    }
}
// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./ICryptoBees.sol";
import "./IHoney.sol";
import "./IHive.sol";
import "./IAttack.sol";
import "./Randomizer.sol";

contract Attack is IAttack, Ownable, Pausable {
    event BearsAttacked(address indexed owner, bytes32 indexed revealHassh, uint256 successes, uint256 value, uint256 errors);

    // reference to the contracts
    IHoney honeyContract = IHoney(0x3E63Aa06691bc9Fd34637f8324D851e51df823D4);
    ICryptoBees beesContract;
    IHive hiveContract;
    Randomizer randomizerContract;

    uint256 public hiveCooldown = 60;
    uint256 public bearChance = 50;
    uint256 public bearCooldownBase = 16 * 3600;
    uint256 public bearCooldownPerHiveDay = 4 * 3600;

    /**
     */
    constructor() {}

    function setContracts(
        address _HONEY,
        address _BEES,
        address _HIVE,
        address _RAND
    ) external onlyOwner {
        honeyContract = IHoney(_HONEY);
        beesContract = ICryptoBees(_BEES);
        hiveContract = IHive(_HIVE);
        randomizerContract = Randomizer(_RAND);
    }

    function setHiveCooldown(uint256 cooldown) external onlyOwner {
        hiveCooldown = cooldown;
    }

    function setBearCooldownBase(uint256 cooldown) external onlyOwner {
        bearCooldownBase = cooldown;
    }

    function setBearCooldownPerHiveDay(uint256 cooldown) external onlyOwner {
        bearCooldownPerHiveDay = cooldown;
    }

    function setBearChance(uint256 chance) external onlyOwner {
        hiveCooldown = chance;
    }

    /** ATTACKS */
    function checkForDuplicates(uint16[] calldata hiveIds) internal pure {
        bool duplicates;
        for (uint256 i = 0; i < hiveIds.length; i++) {
            for (uint256 y = 0; y < hiveIds.length; y++) {
                if (i != y && hiveIds[i] == hiveIds[y]) duplicates = true;
            }
        }
        require(!duplicates, "CANNOT ATTACK SAME HIVE WITH TWO BEARS");
    }

    function manyBearsAttack(
        bytes32 revealHash,
        uint16[] calldata tokenIds,
        uint16[] calldata hiveIds,
        bool transfer
    ) external whenNotPaused _updateEarnings {
        require(tokenIds.length == hiveIds.length, "THE ARGUMENTS LENGTHS DO NOT MATCH");
        require(randomizerContract.canRandomizeForAddress(_msgSender()), "PLEASE FIRST COMMIT A HASH");
        uint256 owed = 0;
        uint256 successes = 0;
        uint256 errors = 0;
        checkForDuplicates(hiveIds);
        uint256 seed = randomizerContract.commitRevealSeed(revealHash);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(beesContract.getOwnerOf(tokenIds[i]) == _msgSender(), "YOU ARE NOT THE OWNER");
            require(beesContract.getTokenData(tokenIds[i])._type == 2, "TOKEN NOT A BEAR");

            // check if hive is attackable
            if (hiveContract.getLastStolenHoneyTimestamp(hiveIds[i]) + hiveCooldown > block.timestamp) {
                errors += 1;
                continue;
            }
            // check if bear can attack
            if (beesContract.getTokenData(tokenIds[i]).cooldownTillTimestamp < block.timestamp) {
                errors += 1;
                continue;
            }
            (owed, successes) = hovno(seed, tokenIds[i], hiveIds[i]);
            hiveContract.incTotalAttacks(hiveIds[i]);

            if (!transfer) beesContract.increaseTokensPot(tokenIds[i], uint32(owed));
            hiveContract.setLastStolenHoneyTimestamp(hiveIds[i], uint48(block.timestamp));
            uint48 hiveAge = hiveContract.getHiveAge(hiveIds[i]);
            uint256 cooldown = ((((block.timestamp - hiveAge) / 86400) * bearCooldownPerHiveDay) + bearCooldownBase) * 3600;

            beesContract.updateTokensLastAttack(tokenIds[i], uint48(block.timestamp), uint48(block.timestamp + cooldown));
        }
        emit BearsAttacked(_msgSender(), revealHash, successes, owed, errors);
        if (transfer && owed > 0) honeyContract.mint(_msgSender(), owed);
    }

    function hovno(
        uint256 seed,
        uint256 tokenId,
        uint256 hiveId
    ) private returns (uint256, uint256) {
        uint256 owed = 0;
        uint256 successes = 0;
        uint256 beesAffected = hiveContract.getHiveOccupancy(hiveId) / 10;
        if (beesAffected == 0) beesAffected = 1;
        for (uint256 y = 0; y < beesAffected; y++) {
            if (((random(seed + tokenId + y) & 0xFFFF) % hiveContract.getHiveOccupancy(hiveId)) < bearChance) {
                uint256 beeId = hiveContract.getBeeTokenId(hiveId, y);
                owed += hiveContract.calculateBeeOwed(hiveId, beeId);
                hiveContract.setBeeSince(hiveId, beeId, uint48(block.timestamp));
                hiveContract.incSuccessfulAttacks(hiveId);
                successes += 1;
            }
            if (successes >= (beesAffected / 2)) break;
        }
        return (owed, successes);
    }

    /**
     * tracks $HONEY earnings to ensure it stops once 2.4 billion is eclipsed
     */
    modifier _updateEarnings() {
        // if (totalHoneyEarned < MAXIMUM_GLOBAL_HONEY) {
        //     totalHoneyEarned += ((block.timestamp - lastClaimTimestamp) * totalBeesStaked * DAILY_HONEY_RATE) / 1 days;
        //     lastClaimTimestamp = block.timestamp;
        // }
        _;
    }

    /**
     * generates a pseudorandom number
     * @param seed a value ensure different outcomes for different sources in the same block
     * @return a pseudorandom value
     */
    function random(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tx.origin, block.timestamp, seed))); //blockhash(block.number - 1),
    }
}
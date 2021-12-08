// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./ICryptoBees.sol";
import "./IHoney.sol";
import "./IHive.sol";
import "./IAttack.sol";

contract Attack is IAttack, Ownable, Pausable {
    event BearsAttacked(address indexed owner, uint256 indexed nonce, uint256 successes, uint256 value, uint256 errors);

    // reference to the contracts
    IHoney honeyContract = IHoney(0x3E63Aa06691bc9Fd34637f8324D851e51df823D4);
    ICryptoBees beesContract;
    IHive hiveContract;

    uint256 public hiveCooldown = 60;

    /**
     */
    constructor() {}

    function setHoneyContract(address _HONEY_CONTRACT) external onlyOwner {
        honeyContract = IHoney(_HONEY_CONTRACT);
    }

    function setBeesContract(address _BEES_CONTRACT) external onlyOwner {
        beesContract = ICryptoBees(_BEES_CONTRACT);
    }

    function setHiveContract(address _HIVE_CONTRACT) external onlyOwner {
        hiveContract = IHive(_HIVE_CONTRACT);
    }

    function setHiveCooldown(uint256 cooldown) external onlyOwner {
        hiveCooldown = cooldown;
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
        uint256 nonce,
        uint16[] calldata tokenIds,
        uint16[] calldata hiveIds,
        bool transfer
    ) external whenNotPaused _updateEarnings {
        require(tokenIds.length == hiveIds.length, "THE ARGUMENTS LENGTHS DO NOT MATCH");
        uint256 owed = 0;
        uint256 successes = 0;
        uint256 errors = 0;
        checkForDuplicates(hiveIds);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(beesContract.getOwnerOf(tokenIds[i]) == _msgSender(), "YOU ARE NOT THE OWNER");
            require(beesContract.getTokenData(tokenIds[i])._type == 2, "TOKEN NOT A BEAR");

            // check if bear can attack
            if (hiveContract.getLastStolenHoneyTimestamp(hiveIds[i]) + hiveCooldown > block.timestamp) {
                errors += 1;
                continue;
            }
            uint256 beesAffected = hiveContract.getHiveOccupancy(hiveIds[i]) / 10;
            if (beesAffected == 0) beesAffected = 1;

            for (uint256 y = 0; y < beesAffected; y++) {
                if (((random(tokenIds[i] + y) & 0xFFFF) % hiveContract.getHiveOccupancy(hiveIds[i])) < 50) {
                    uint256 tokenId = hiveContract.getBeeTokenId(hiveIds[i], y);
                    owed += hiveContract.calculateBeeOwed(hiveIds[i], tokenId);
                    hiveContract.setBeeSince(hiveIds[i], tokenId, uint48(block.timestamp));
                    hiveContract.incSuccessfulAttacks(hiveIds[i]);
                    successes += 1;
                }
            }
            hiveContract.incTotalAttacks(hiveIds[i]);

            if (!transfer) beesContract.increateTokensPot(tokenIds[i], uint32(owed));
            hiveContract.setLastStolenHoneyTimestamp(hiveIds[i], uint48(block.timestamp));
            beesContract.updateTokensLastAttack(tokenIds[i], uint48(block.timestamp), uint48(block.timestamp + 120));
        }
        emit BearsAttacked(_msgSender(), nonce, successes, owed, errors);
        if (transfer && owed > 0) honeyContract.mint(_msgSender(), owed);
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
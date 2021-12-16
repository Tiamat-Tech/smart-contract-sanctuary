// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Interfaces.sol";

contract CrystalManaCalculator is ICrystalManaCalculator {
    ICrystals public iCrystals;

    constructor(address crystalsAddress) { 
        iCrystals = ICrystals(crystalsAddress);
    }

    function claimableMana(uint256 crystalId) override public view returns (uint32) {
        uint256 daysSinceClaim = diffDays(
            iCrystals.crystalsMap(crystalId).lastClaim,
            block.timestamp
        );

        if (block.timestamp - iCrystals.crystalsMap(crystalId).lastClaim < 1 days) {
            return 0;
        }

        uint32 manaToProduce = uint32(daysSinceClaim) * iCrystals.getResonance(crystalId);

        // if capacity is reached, limit mana to capacity, ie Spin
        if (manaToProduce > iCrystals.getSpin(crystalId)) {
            manaToProduce = iCrystals.getSpin(crystalId);
        }

        return manaToProduce;
    }

    function diffDays(uint256 fromTimestamp, uint256 toTimestamp)
        internal
        pure
        returns (uint256)
    {
        require(fromTimestamp <= toTimestamp);
        return (toTimestamp - fromTimestamp) / (24 * 60 * 60);
    }
}
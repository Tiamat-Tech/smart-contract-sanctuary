pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Interfaces.sol";

contract CrystalManaCalculator is Ownable, ICrystalManaCalculator {
    ICrystals public iCrystals;

    constructor(address crystalsAddress) Ownable() { 
        iCrystals = ICrystals(crystalsAddress);
    }

    function claimableMana(uint256 tokenId) override public view returns (uint256) {
        uint256 daysSinceClaim = diffDays(
            iCrystals.crystalsMap(tokenId).lastClaim,
            block.timestamp
        );

        require(daysSinceClaim >= 1, "NONE");

        uint256 manaToProduce = daysSinceClaim * iCrystals.getResonance(tokenId);

        // if cap is hit, limit mana to cap or level, whichever is greater
        if ((manaToProduce + iCrystals.crystalsMap(tokenId).manaProduced) > iCrystals.getSpin(tokenId)) {
            if (iCrystals.getSpin(tokenId) >= iCrystals.crystalsMap(tokenId).manaProduced) {
                manaToProduce = iCrystals.getSpin(tokenId) - iCrystals.crystalsMap(tokenId).manaProduced;
            } else {
                manaToProduce = 0;
            }

            if (manaToProduce < iCrystals.crystalsMap(tokenId).level) {
                manaToProduce = iCrystals.crystalsMap(tokenId).level;
            }
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
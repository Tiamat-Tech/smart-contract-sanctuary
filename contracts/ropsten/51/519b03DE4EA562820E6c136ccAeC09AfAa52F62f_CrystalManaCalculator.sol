pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Interfaces.sol";

contract CrystalManaCalculator is Ownable, ICrystalManaCalculator {
    ICrystals public iCrystals;

    constructor(address crystalsAddress) Ownable() { 
        iCrystals = ICrystals(crystalsAddress);
    }

    function ownerSetCrystalsAddress(address addr) public onlyOwner {
        iCrystals = ICrystals(addr);
    }

    function claimableMana(uint256 crystalId) override public view returns (uint256) {
        uint256 daysSinceClaim = diffDays(
            iCrystals.crystalsMap(crystalId).lastClaim,
            block.timestamp
        );

        if (block.timestamp - iCrystals.crystalsMap(crystalId).lastClaim < 1 days) {
            return 0;
        }

        uint256 manaToProduce = daysSinceClaim * iCrystals.getResonance(crystalId);

        // if cap is hit, limit mana to cap or level, whichever is greater
        if ((manaToProduce + iCrystals.crystalsMap(crystalId).levelManaProduced) > iCrystals.getSpin(crystalId)) {
            if (iCrystals.getSpin(crystalId) >= iCrystals.crystalsMap(crystalId).levelManaProduced) {
                manaToProduce = iCrystals.getSpin(crystalId) - iCrystals.crystalsMap(crystalId).levelManaProduced;
            } else {
                manaToProduce = 0;
            }

            if (manaToProduce < iCrystals.crystalsMap(crystalId).level) {
                manaToProduce = iCrystals.crystalsMap(crystalId).level;
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
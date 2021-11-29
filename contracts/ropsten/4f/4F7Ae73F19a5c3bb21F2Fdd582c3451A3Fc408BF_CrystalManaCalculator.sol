// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Mana.sol";
import "./ICrystals.sol";

interface ICrystalManaCalculator {
    function claimableMana(uint256 tokenId) external view returns (uint256);
}

contract CrystalManaCalculator is Ownable, ICrystalManaCalculator {
    address public crystalsAddress;

    constructor(address _crystals) Ownable() { 
        crystalsAddress = _crystals;
    }

    function claimableMana(uint256 tokenId) override public view returns (uint256) {
        ICrystals crystals = ICrystals(crystalsAddress);

        uint256 daysSinceClaim = diffDays(
            crystals.crystalsMap(tokenId).lastClaim,
            block.timestamp
        );

        require(daysSinceClaim >= 1, "NONE");

        uint256 manaToProduce = daysSinceClaim * crystals.getResonance(tokenId);

        // if cap is hit, limit mana to cap or level, whichever is greater
        if ((manaToProduce + crystals.crystalsMap(tokenId).manaProduced) > crystals.getSpin(tokenId)) {
            if (crystals.getSpin(tokenId) >= crystals.crystalsMap(tokenId).manaProduced) {
                manaToProduce = crystals.getSpin(tokenId) - crystals.crystalsMap(tokenId).manaProduced;
            } else {
                manaToProduce = 0;
            }

            if (manaToProduce < crystals.crystalsMap(tokenId).level) {
                manaToProduce = crystals.crystalsMap(tokenId).level;
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
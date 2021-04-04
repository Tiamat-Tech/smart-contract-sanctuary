// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Rarity {

    using EnumerableSet for EnumerableSet.UintSet;

    // 0.90 || 0.09 || 0.009 || 0.0009 || 0.0001 -- 4 decimal system
    enum TokenRarity {Common, Uncommon, Rare, Epic, Legendary}

    /// @notice The `rarity` is assigned in a pseudo random manner; must be made truly random for production.
    function getRandomRarity() public view returns (uint rarity) {
        uint slot = (block.number + block.timestamp) % (10**4); // Pseudo random. Can easily be manipulated by miners.

        if(slot < 1) {
            rarity = uint(TokenRarity.Legendary);
        } else if (slot < 10) {
            rarity = uint(TokenRarity.Epic);
        } else if (slot < 100) {
            rarity = uint(TokenRarity.Rare);
        } else if (slot < 1000) {
            rarity = uint(TokenRarity.Uncommon);
        } else {
            rarity = uint(TokenRarity.Common);
        }
    }

    /// @notice Get the pool share entitled to the rarity category
    function getPoolShareByRarity(uint _rarity, uint _pool) public pure returns (uint poolByRarity) {

        if(_rarity == uint(TokenRarity.Common)) {
            poolByRarity = (_pool*1)/(10**4);
        
        } else if (_rarity == uint(TokenRarity.Uncommon)) {
            poolByRarity = (_pool*9)/(10**4);

        } else if (_rarity == uint(TokenRarity.Rare)) {
            poolByRarity = (_pool*90)/(10**4);
            
        } else if (_rarity == uint(TokenRarity.Epic)) {
            poolByRarity = (_pool*900)/(10**4);
            
        } else if (_rarity == uint(TokenRarity.Legendary)) {
            poolByRarity = (_pool*9000)/(10**4);
            
        } else {
            revert("The token has invalid rarity. This should be impossible.");
        }
    }
}
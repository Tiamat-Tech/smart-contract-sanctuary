// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "./Market.sol";
import "hardhat/console.sol";

contract Attack is NFTMarket {

  event LevelUp (
    uint indexed itemId,
    uint level,
    uint exp,
    uint time
  );

  function attack(uint itemId, uint _targetId, address nftContract) external {
    uint tokenId = idToMarketItem[itemId].tokenId;
    uint readyTime = idToMarketItem[itemId].readyTime;

    require(msg.sender == IERC721(nftContract).ownerOf(tokenId), "You isn't a owner");
    require(readyTime <= block.timestamp, "Your Ant isn't ready");

    MarketItem storage myItem = idToMarketItem[itemId];
    MarketItem storage enemyItem = idToMarketItem[_targetId];
    uint rand = randomNumber(100);
    uint attackVictoryProbability = _getAttackVictoryProbability(myItem, enemyItem);
    if (rand <= attackVictoryProbability) {
      _winer(myItem, attackVictoryProbability, enemyItem);
    } else {
      _lost(myItem, attackVictoryProbability, enemyItem);
    }
  }

  function _getAttackVictoryProbability(MarketItem storage myItem, MarketItem storage enemyItem) internal view returns(uint) {
    uint myItemExp = (myItem.exp + 1) * _sqrt(uint(myItem.rare));
    uint enemyItemExp = (enemyItem.exp + 1) * _sqrt(uint(enemyItem.rare));
    uint percent = 100 * myItemExp / (myItemExp + enemyItemExp);
    uint maxPercent = 80;
    uint minPercent = 20;

    if(percent > maxPercent){
      return maxPercent;
    }else if(percent < minPercent){
      return minPercent;
    }else{
      return percent;
    }
  }

  function _sqrt(uint x) internal pure returns (uint y) {
    uint z = (x + 1) / 2;
    y = x;
    while (z < y) {
        y = z;
        z = (x / z + z) / 2;
    }
  }

  function _winer(MarketItem storage item, uint percent, MarketItem storage enemyItem) internal {
    item.exp = item.exp + item.level * 5 + enemyItem.level * (100 - percent)/10;
    _getLevel(item);
    _triggerCooldown(item);
    bytes memory data = "win";
    antToken.operatorSend(address(this), msg.sender, enemyItem.price, data, data);
    emit LevelUp(item.itemId, item.level, item.exp, block.timestamp);
  }

  function _lost(MarketItem storage item, uint percent, MarketItem storage enemyItem) internal {
    uint exp = (item.level * 5 + enemyItem.level * (100 - percent)/10 ) / 2;
    if(exp >= item.exp){
      item.exp = 1;
    }else{
      item.exp = item.exp - exp;
    }
    _getLevel(item);
    _triggerCooldown(item);
    bytes memory data = "lost";
    antToken.operatorSend(msg.sender, address(this), enemyItem.price / 2, data, data);
    emit LevelUp(item.itemId, item.level, item.exp, block.timestamp);
  }

  function _triggerCooldown(MarketItem storage item) internal {
    uint16 count = item.attackCount + 1;
    item.attackCount = item.attackCount + 1;
    if(count % 2 == 0){
      item.readyTime = cooldownTime(item.rare);
    }
  }

  function _getLevel(MarketItem storage item) internal {
    if(item.exp >= 4000){
      item.level = 6;
    }else if(item.exp >= 350){
      item.level = 5;
    }else if(item.exp >= 2000){
      item.level = 4;
    }else if(item.exp >= 350){
      item.level = 3;
    }else if(item.exp >= 100){
      item.level = 2;
    } 
  }

}
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Betting is Ownable {  
  IERC20 private scaleToken;

  address payable wallet;

  mapping (address => uint) private bets;
  mapping (address => uint) private rewards;

  uint private playersCount;

  event BetPlaced(address sender, uint amount);
  event AwardRecieved(address reciever, uint amount);
  event PLayerKilled(address killer, address victim);

  constructor(address payable walletAddress, address scaleTokenAddress) {
    playersCount = 0;
    wallet = walletAddress;
    scaleToken = IERC20(scaleTokenAddress);
  }

  function newBet(uint amount) public {
    require(amount > 0, "Bet must be greather zero.");

    scaleToken.transferFrom(msg.sender, address(this), amount);    
    bets[msg.sender] = amount; 
    playersCount++;

    emit BetPlaced(msg.sender, amount);
  }

  function claimRewards() external {
    address player = msg.sender;
    uint reward = rewards[player] + bets[player];
    uint comission = reward * 20 / 100;
    
    scaleToken.transfer(player, reward - comission);
    scaleToken.transfer(wallet, comission);
    
    rewards[player] = 0;
    bets[player] = 0;

    emit AwardRecieved(player, reward);
  } 

  function playerKilled(address killer, address victim) external onlyOwner {
    uint reward = bets[victim] < bets[killer] ? bets[victim] : bets[killer];
    
    bets[victim] = 0;
    rewards[killer] = reward;
    playersCount--;

    emit PLayerKilled(killer, victim);
  }

  function isPlayerInGame(address player) external view returns(bool) {
    return bets[player] == 0 ? false : true;
  } 

  function getBetsByUser(address playerAddress) external view returns(uint) {
    return bets[playerAddress];
  }

  function getCurrentRewardByUser(address playerAddress) external view returns(uint) {
    return rewards[playerAddress];
  }

  function getPlayersCount() external view returns(uint) {
    return playersCount;
  }
}
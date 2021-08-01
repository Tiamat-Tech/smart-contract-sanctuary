// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/security/PullPayment.sol";

contract PaymentGateway is Ownable,PullPayment{
  function deposit(uint256 amount) public  returns (bool) {
  }
}

contract Competition {
   address payable public owner;
   uint256 public minimumBet;
   uint256 public totalBets;
   address payable[] public players;
   struct Player {
      uint256 amountBet;
      uint16 gameSelected;
    }
    // The address of the player and => the user info
   mapping(address => Player) public playerInfo;
   //function() external payable {};

    constructor() {
      owner = payable(msg.sender);
      minimumBet = 100000000000000;
    }
    function kill() public {
      if(msg.sender == owner) selfdestruct(owner);
    }

    function checkPlayerExists(address payable player) public view returns(bool){
      for(uint256 i = 0; i < players.length; i++){
         if(players[i] == player) return true;
      }
      return false;
    }

    function bet(uint8 _gameSelected) public payable {
        //The first require is used to check if the player already exist
        require(!checkPlayerExists(payable(msg.sender)));
        //The second one is used to see if the value sended by the player is
        //Higher than the minimum value
        require(msg.value >= minimumBet);
        //We set the player informations : amount of the bet and selected team
        playerInfo[msg.sender].amountBet = msg.value;
        playerInfo[msg.sender].gameSelected = _gameSelected;
        //then we add the address of the player to the players array
        players.push(payable(msg.sender));
        //at the end, we increment the stakes of the game selected with the player bet
        totalBets += msg.value;
        PaymentGateway escrow = new PaymentGateway();
        escrow.deposit(totalBets);

    }
    // Generates a number between 1 and 10 that will be the winner
    function distributePrizes(address payable playerAddress) public {
        //Transfer the money to the user
        playerAddress.transfer(totalBets);
        //PaymentGateway escrow = new PaymentGateway();
        delete playerInfo[playerAddress]; // Delete all the players
        //players.length = 0; // Delete all the players array
        totalBets = 0;
    }
    function WinnersPrize() public view returns(uint256){
        return totalBets;
    }
}
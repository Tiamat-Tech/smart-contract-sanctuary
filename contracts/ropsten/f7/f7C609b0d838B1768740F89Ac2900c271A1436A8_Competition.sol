// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/security/PullPayment.sol";
import "./Token.sol";
contract PaymentGateway is Ownable,PullPayment{
  function deposit(uint256 amount) public  returns (bool) {
  }
}

contract Competition is Ownable,RToken{
   //address payable public owner;
   uint256  minimumBet;
   uint256  totalBets;
   address payable[] public players;
   struct Player {
      uint256 amountBet;
      uint16 gameSelected;
    }
    // The address of the player and => the user info
   mapping(address => Player) public playerInfo;
   //function() external payable {};

    constructor(uint256  minimum_Bet) {
      //owner = payable(msg.sender);
      minimumBet = minimum_Bet;
      
    }
    function addPlayer(address player) public onlyOwner returns(bool){
        require(!checkPlayerExists(payable(player))," Player already Exists");
        players.push(payable(player));
        return true;    
        
    }
    
    function kill() onlyOwner public {
      selfdestruct(payable(owner()));
    }

    function checkPlayerExists(address payable player) public view returns(bool){
      for(uint256 i = 0; i < players.length; i++){
         if(players[i] == player) return true;
      }
      return false;
    }

    function bet(uint256 _bet) public payable {
        //The first require is used to check if the player already exist
        require(checkPlayerExists(payable(msg.sender)),"Player does not exist in this competiotion");
        //The second one is used to see if the value sended by the player is
        //Higher than the minimum value
        require(_bet >= minimumBet,"Bet placed is lower than minimum Bet accepted for this Competition");
        //Ensure that Player has sufficient balance of Rtokens
        require(balanceOf(msg.sender) >= _bet, "Your Balance is insufficient to place the bet");
        //We set the player informations : amount of the bet and selected team
        playerInfo[msg.sender].amountBet = _bet;
        playerInfo[msg.sender].gameSelected = 0;
        //then we add the address of the player to the players array
        players.push(payable(msg.sender));
        //at the end, we increment the stakes of the game selected with the player bet
        totalBets += _bet;
        PaymentGateway escrow = new PaymentGateway();
        escrow.deposit(totalBets);
    }
    // Generates a number between 1 and 10 that will be the winner
    function distributePrizes(address payable playerAddress) onlyOwner public {
        //Transfer the money to the user
        transferWithFee(playerAddress,totalBets);
        //PaymentGateway escrow = new PaymentGateway();
        //delete playerInfo[playerAddress]; // Delete all the players
        //players.length = 0; // Delete all the players array
        totalBets = 0;
    }
    function WinnersPrize() public view returns(uint256){
        return totalBets;
    }
}
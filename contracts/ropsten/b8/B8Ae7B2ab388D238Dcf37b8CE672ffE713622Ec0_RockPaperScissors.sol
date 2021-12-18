import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


interface IRockPaperScissors {

}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract RockPaperScissors {
    enum Hand { IDLE, ROCK, PAPER, SCISSORS }
    struct PlayerBet {
        bytes32 encryptedMove;
        uint256 bet;
    }
    mapping(address => PlayerBet[]) public playerToBets;
    mapping(address => uint256) public playerToId;
    address[] public enrolledPlayers;
    //PlayerBet private _bet;

    function enroll(bytes32 _encryptedMove) external payable {
        if (playerToId[msg.sender] == 0) {
            enrolledPlayers.push(msg.sender);
            playerToId[msg.sender] = enrolledPlayers.length - 1;
        }
        PlayerBet memory newBet;
        newBet.encryptedMove = _encryptedMove;
        newBet.bet = msg.value;
        playerToBets[msg.sender].push(newBet);
    }

    function getEnrolledPlayers() external view returns(address[] memory) {
        return enrolledPlayers;
    }

    function getPlayerBets(address _player) external view returns(PlayerBet[] memory) {
        return playerToBets[_player];
    }
}
// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "viterVpoliToken.sol";
pragma solidity 0.8.4;

import "hardhat/console.sol";

contract Lottery {
    IERC20 tokenVVPT =
        IERC20(address(0x3E0DD4d6AEee8721329421a494B7f996Fe08e7Ef));
    address public owner;
    address[] players;
    uint256 public endplayers;
    uint256 public endTime;
    uint256 public ticketPrice;
    // uint256 public amountTicket = 0;
    uint256 public interest;
    uint256 public payComission = 0;
    address public lastWinner;

    event LogWinnerSelected(address winner);
    event lotterySalary(uint256 lotteryBalance);
    event GoToStartLottery(
        uint256 _ticketPrice,
        uint256 _lotteryTime,
        uint256 _endPlayers,
        uint256 _interest
    );
    event ticketPurchase(address _player, uint256 _amountTicket);

    modifier isActive() {
        require(
            endplayers != players.length && block.timestamp < endTime,
            "Lottery is not active"
        );
        _;
    }

    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    constructor(
        uint256 _ticketPrice,
        uint256 _lotteryTime,
        uint256 _endPlayers,
        uint256 _interest
    ) {
        owner = msg.sender;
        startLottery(_ticketPrice, _lotteryTime, _endPlayers, _interest);
    }

    function startLottery(
        uint256 _ticketPrice,
        uint256 _lotteryTime,
        uint256 _endPlayers,
        uint256 _interest
    ) public isOwner {
        endplayers = _endPlayers;
        interest = _interest;
        ticketPrice = _ticketPrice;
        endTime = block.timestamp + _lotteryTime;
        emit GoToStartLottery(endplayers, endTime, ticketPrice, interest);
    }

    function enter(uint256 amountToken) external isActive {
        tokenVVPT.transferFrom(msg.sender, address(this), amountToken);
        payComission = payComission + ((amountToken * interest) / 100);
        uint256 amountTicket = (amountToken / ticketPrice);

        for (uint256 i = 0; i < amountTicket; amountTicket--) {
            if (players.length < endplayers) {
                players.push(msg.sender);
            } else {
                break;
            }
        }
        emit ticketPurchase(msg.sender, amountTicket);
    }

    function getPlayers() external view returns (address[] memory, uint256) {
        return (players, players.length);
    }

    function winner() external isOwner {
        require(
            block.timestamp > endTime || endplayers == players.length,
            "locked"
        );

        uint256 indexWin = (
            uint256(keccak256(abi.encode(block.difficulty + block.number)))
        ) % players.length;

        if (players.length < endplayers) {
            tokenVVPT.transfer(
                players[indexWin],
                (ticketPrice * players.length) / 2
            );
        } else {
            tokenVVPT.transfer(
                players[indexWin],
                (ticketPrice * players.length) - payComission
            );
        }

        lastWinner = players[indexWin];
        emit LogWinnerSelected(players[indexWin]);
        players = new address[](0);
        endplayers = 0;
        ticketPrice = 0;
        interest = 0;
    }

    function exhaust() external isOwner {
        require(endplayers == 0, "locked");
        uint256 lotteryBalance = tokenVVPT.balanceOf(address(this));
        emit lotterySalary(lotteryBalance);
        tokenVVPT.transfer(msg.sender, lotteryBalance);
        payComission = 0;
    }
}
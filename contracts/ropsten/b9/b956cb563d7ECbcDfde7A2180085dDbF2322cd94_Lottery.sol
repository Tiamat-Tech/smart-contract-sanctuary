// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import "hardhat/console.sol";

contract Lottery {
    address public owner;
    address payable[] players;
    uint256 public endplayers;
    uint256 public endTime;
    uint256 public ticketPrice;
    // uint256 public amountTicket = 0;
    uint256 public interest;
    uint256 private payComission;
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
        unchecked {
            endTime = block.timestamp + _lotteryTime;
        }
        emit GoToStartLottery(endplayers, endTime, ticketPrice, interest);
    }

    function enter() external payable isActive {
        require(msg.value >= ticketPrice, "insufficient funds");
        unchecked {
            payComission = (msg.value * interest) / 100;
        }
        uint256 amountTicket = (msg.value / ticketPrice);

        for (uint256 i = 0; i < amountTicket; amountTicket--) {
            if (players.length < endplayers) {
                players.push(payable(msg.sender));
            } else {
                break;
            }
        }
        emit ticketPurchase(msg.sender, amountTicket);
    }

    function getPlayers()
        external
        view
        returns (address payable[] memory, uint256)
    {
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
            players[indexWin].transfer((ticketPrice * players.length) / 2);
        } else {
            players[indexWin].transfer(
                (ticketPrice * players.length) - payComission
            );
        }

        lastWinner = players[indexWin];
        emit LogWinnerSelected(players[indexWin]);
        players = new address payable[](0);
        endplayers = 0;
        ticketPrice = 0;
        interest = 0;
    }

    function exhaust() external isOwner {
        require(endplayers == 0, "locked");
        emit lotterySalary(address(this).balance);
        payable(msg.sender).transfer(address(this).balance);
    }
}
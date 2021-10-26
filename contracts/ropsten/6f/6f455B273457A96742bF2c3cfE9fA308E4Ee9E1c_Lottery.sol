// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import "hardhat/console.sol";

contract Lottery {
    address public owner;
    address payable[] players;
    uint256 public endplayers;
    uint256 public endTime;
    uint256 public ticketPrice;
    uint256 public amountTicket = 0;
    address public lastWinner;

    event LogWinnerSelected(address winner);
    event lotterySalary(uint256 lotteryBalance);

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
        uint256 _endPlayers
    ) {
        owner = msg.sender;
        startLottery(_ticketPrice, _lotteryTime, _endPlayers);
    }

    function startLottery(
        uint256 _ticketPrice,
        uint256 _lotteryTime,
        uint256 _endPlayers
    ) public isOwner {
        endplayers = _endPlayers;
        unchecked {
            // endTime = block.timestamp + (_lotteryTime * 1 days);
            endTime = block.timestamp + _lotteryTime;
            ticketPrice = _ticketPrice;
        }
    }

    function enter() public payable isActive {
        require(msg.value >= ticketPrice, "insufficient funds");
        amountTicket = (msg.value / ticketPrice);

        for (uint256 i = 0; i < amountTicket; amountTicket--) {
            if (players.length < endplayers) {
                players.push(payable(msg.sender));
            } else {
                break;
            }
        }
    }

    function getPlayers()
        public
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
            players[indexWin].transfer(ticketPrice * players.length);
        }

        lastWinner = players[indexWin];
        players = new address payable[](0);
        endplayers = 0;
        ticketPrice = 0;
        emit LogWinnerSelected(players[indexWin]);
    }

    function exhaust() external isOwner {
        require(endplayers == 0, "locked");
        payable(msg.sender).transfer(address(this).balance);
        emit lotterySalary(address(this).balance);
    }
}
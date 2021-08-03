// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract Lottery is Ownable {
    address public manager;
    address[] public players;
    address[] public winners;

    uint256 public target_amount;
    uint256 public ticket_price;
    uint256 public max_ticket_price;

    bool public isGameEnded = true;
    bool public readyToPickWinner = false;
    uint256 public startedTime = 0;

    IERC20 public toxic;
    IERC20 public detox;

    uint256 public toxic_threshold = 1000000 * 1e9;
    uint256 public detox_threshold = 1000000 * 1e9;
    event PickWinner(address indexed winner, uint256 balance);

    constructor(address _toxic, address _detox) {
        toxic = IERC20(_toxic);
        detox = IERC20(_detox);
        manager = msg.sender;
        isGameEnded = true;
    }

    modifier onGame() {
        require(
            !isGameEnded && !readyToPickWinner,
            "Game has not started yet."
        );
        _;
    }

    function setThresholds(uint256 _toxic_threshold, uint256 _detox_threshold)
        external
        onlyOwner
    {
        toxic_threshold = _toxic_threshold;
        detox_threshold = _detox_threshold;
    }

    function setTokens(address _toxic, address _detox) external onlyOwner {
        toxic = IERC20(_toxic);
        detox = IERC20(_detox);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function enter() public payable onGame {
        require(
            msg.value == ticket_price,
            "Value sent doesnt match the ticket price"
        );
        require(
            target_amount > 0,
            "All the tickets were sold, wait for the next game"
        );
        require(
            toxic.balanceOf(msg.sender) > toxic_threshold,
            "You must hold enough Toxic on your wallet"
        );
        require(
            detox.balanceOf(msg.sender) > detox_threshold,
            "You must hold enough Detox on your wallet"
        );

        players.push(msg.sender);

        target_amount = target_amount - 1;
        if (target_amount == 0) {
            readyToPickWinner = true;
        }
    }

    function initialize(uint256 _ticketPrice, uint256 _ticketAmount)
        public
        onlyOwner
    {
        require(isGameEnded, "Game is running now.");

        startedTime = block.timestamp;
        ticket_price = _ticketPrice;
        target_amount = _ticketAmount;
        isGameEnded = false;
        readyToPickWinner = false;
    }

    function random() private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, players)
                )
            );
    }

    function pickWinner() public onlyOwner {
        require(readyToPickWinner, "Game is running now.");
        uint256 index = random() % players.length;
        address payable winner = payable(players[index]);
        players = new address[](0);
        uint256 winBalance = address(this).balance;
        winner.transfer(address(this).balance);

        isGameEnded = true;
        winners.push(winner);

        emit PickWinner(winner, winBalance);
    }

    function getPlayers() public view returns (address[] memory) {
        return players;
    }

    function getWinners() public view returns (address[] memory) {
        return winners;
    }

    function getPlayersNumber() public view returns (uint256) {
        return players.length;
    }

    function getStartedTime() public view returns (uint256) {
        return block.timestamp - startedTime;
    }

    function getPercent() public view returns (uint256) {
        if (isGameEnded) return 0;
        if (readyToPickWinner) return 100;
        return
            (getPlayersNumber() * 100) / (target_amount + getPlayersNumber());
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Lottery is Ownable {
    using SafeMath for uint256;

    enum LotteryState {
        Open,
        Closed,
        Finished
    }

    LotteryState public state;
    mapping(uint256 => address) numberToAddress;
    mapping(address => bool) hasBoughtTicket;
    uint256[] public numbersLeft;
    uint256[] public numbersTaken;
    uint256 limit;
    uint256 public numberOfEntries;
    uint256 public winningNumber;
    uint256 entryFee;
    uint256 seed;

    event LotteryStateChanged(LotteryState newState);
    event NewEntry(address player, uint256 number);
    event WinningNumber(uint256 winningNumber);

    // modifiers
    modifier isState(LotteryState _state) {
        require(state == _state, "Wrong state for this action");
        _;
    }

    //constructor
    constructor(
        uint256 _entryFee,
        uint256 _limit,
        uint256 _seed
    ) Ownable() {
        require(_entryFee > 0, "Entry fee must be greater than 0");
        entryFee = _entryFee;
        seed = _seed;
        limit = _limit;
        for (uint256 i = 1; i <= limit; i++) {
            numbersLeft.push(i);
        }
        changeState(LotteryState.Open);
    }

    function getNumbersTaken() external view returns (uint256[] memory) {
        return numbersTaken;
    }

    function getNumbersLeft() external view returns (uint256[] memory) {
        return numbersLeft;
    }

    function generateRandomNumberBelow(uint256 _modulus)
        internal
        returns (uint256)
    {
        seed++;
        return
            uint256(
                keccak256(abi.encodePacked(block.timestamp, msg.sender, seed))
            ) % _modulus;
    }

    //functions
    function buyLotteryTicket(uint256 _number)
        external
        payable
        isState(LotteryState.Open)
    {
        require(msg.value == entryFee, "Send exactly the entry fee amount");
        require(
            !hasBoughtTicket[msg.sender],
            "Cannot buy more than one ticket"
        );
        require(
            numberToAddress[_number] == address(0),
            "Ticket number has been bought already :("
        );
        require(_number <= limit && _number > 0, "Number must be within limit");

        hasBoughtTicket[msg.sender] = true;
        numberToAddress[_number] = msg.sender;
        numbersTaken.push(_number);
        numberOfEntries++;

        uint256 indexToRemove = 0;
        for (uint256 i = 0; i < numbersLeft.length; i++) {
            if (numbersLeft[i] == _number) {
                indexToRemove = i;
                break;
            }
        }
        numbersLeft[indexToRemove] = numbersLeft[numbersLeft.length - 1];
        numbersLeft.pop();

        emit NewEntry(msg.sender, _number);
    }

    function drawNumber() external onlyOwner isState(LotteryState.Closed) {
        winningNumber = numbersTaken[
            generateRandomNumberBelow(numberOfEntries)
        ];
        payable(numberToAddress[winningNumber]).transfer(address(this).balance);
        changeState(LotteryState.Finished);
    }

    function changeState(LotteryState _newState) public onlyOwner {
        state = _newState;
        emit LotteryStateChanged(state);
    }

    function startNewLottery(uint256 _entryFee, uint256 _limit)
        external
        onlyOwner
        isState(LotteryState.Finished)
    {
        changeState(LotteryState.Open);
        delete numbersLeft;
        delete numbersTaken;
        for (uint256 i = 0; i < limit; i++) {
            hasBoughtTicket[numberToAddress[i]] = false;
            numberToAddress[i] = address(0);
        }
        limit = _limit;
        entryFee = _entryFee;
        winningNumber = 0;
        numberOfEntries = 0;
        for (uint256 i = 1; i <= limit; i++) {
            numbersLeft.push(i);
        }
    }
}
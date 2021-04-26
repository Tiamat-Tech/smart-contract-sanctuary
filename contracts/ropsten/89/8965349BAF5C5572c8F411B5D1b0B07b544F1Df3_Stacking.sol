//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./Stacking.sol";

contract PotatoGame is ERC20, Ownable {
    using SafeCast for uint;
    using SafeCast for uint64;
    uint64 private _finishedAt = 0;
    uint64 private _price = 100000000 gwei; // 10^8 gwei = 0.1 ether
    uint8 private _duration = 100; // duration is in the hours only
    uint8 private _burnPrice = 10;
    address private _winner;
    Stacking private _stacking;
    constructor() ERC20("PotatoGame", "PGC") Ownable() {
    }

    modifier notGameOver() {
        require(_finishedAt > block.timestamp, "Game over");
        _;
    }

    modifier gameOver() {
        require(_finishedAt <= block.timestamp, "Game over");
        _;
    }

    modifier onlyWinner() {
        require(msg.sender == _winner, "Only for winners");
        _;
    }

    modifier stackerDefined() {
        require(address(_stacking) != address(0), "Stacking is not defined");
        _;
    }

    function setStake(Stacking stacking) external onlyOwner {
        _stacking = stacking;
    }

    function _updateStarted() private {
        if (_finishedAt < block.timestamp + 1 hours) {
            _finishedAt = (block.timestamp - 1 hours).toUint64();
        } else {
            _finishedAt = (_finishedAt + 1 hours).toUint64();
        }
    }

    function _startOrContinue() private {
        if (_finishedAt == 0) {
            _finishedAt = (block.timestamp + _duration * 1 hours).toUint64();
        } else {
            _updateStarted();
        }
    }

    function click() external payable notGameOver {
        require(msg.value == _price, "Only exact amount is accepted");
        _winner = msg.sender;
        _mint(msg.sender, 1);
        _startOrContinue();
    }

    function burn() external notGameOver {
        uint256 senderBalance = balanceOf(msg.sender);
        require(senderBalance >= _burnPrice , "Not enough tokens");
        _burn(msg.sender, _burnPrice);
        _winner = msg.sender;
        _startOrContinue();
    }
    
    function claimAward() external gameOver onlyWinner {
        require(address(this).balance > _price, "Not enough funds to return");
        _finishedAt = (block.timestamp + _duration * 1 hours).toUint64();
        _winner = msg.sender;
        _mint(msg.sender, 1);
        this.transfer(msg.sender, address(this).balance - _price);
    }

    function stake(uint256 amount) external stackerDefined {
        uint256 senderBalance = balanceOf(msg.sender);
        require(senderBalance > 0, "No tokens found");
        require(senderBalance <= amount, "Not enough tokens");
        require(0 == amount, "Zero cannot be stacked");
        _burn(msg.sender, amount);
        _stacking.stake(msg.sender, amount);
    }

    function unstake(uint256 amount) external stackerDefined {
        bool result =_stacking.unstake(msg.sender, amount);
        if (result) {
            _mint(msg.sender, amount);
        }
    }

}
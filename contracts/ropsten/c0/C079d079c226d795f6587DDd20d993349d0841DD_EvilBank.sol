//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract EvilBank is Ownable, ReentrancyGuard {
    
    uint public duration = 1 minutes; 
    uint public minStartBid = 0.001 ether;
    uint public minBidIncreasePercent = 10;
    uint public directorRewardPercent = 5;
    uint public ownerRewardPercent = 1;

    // Current game status
    uint public gameId = 0;
    address public director;
    uint public currentBid;
    uint public endsAt;
    bool public running = false;

    // Game balance
    uint public gameBalance;

    // @notice used to store balance to be withdrawn by a user in case a payable.send fails
    mapping(address => uint) public withdrawable;

    // @notice used to build the bids history on the front-end
    event Bid (uint indexed gameId, uint bid, address director);
    event GameStart (uint indexed gameId, uint bid, address director);
    event GameEnd (uint indexed gameId, uint amount, address director);

    // @notice Bid was insufficient
    error InsufficientBid(uint min);
    error ToEarlyToEnd(uint endsAt);
    error NothingToWithdraw();

    // @notice returns the minimum bid value for a bid to be processed
    // @return minimal value for a bid to be accepted
    function minBid() public view returns(uint) {
        if(block.timestamp >= endsAt) return minStartBid;
       
        return currentBid * (100 + minBidIncreasePercent) / 100;
    }

    // @notice allows owner to change duration of games
    function setDuration(uint _duration) external onlyOwner {
        require(!running);
        duration = _duration;
    }

    // @notice allows owner to change the minimum percent increase of bids
    // @param _minBidIncreasePercent new value
    function setMinBidIncreasePercent(uint _minBidIncreasePercent) external onlyOwner {
        require(_minBidIncreasePercent > 0);
        require(!running && directorRewardPercent + ownerRewardPercent < _minBidIncreasePercent);
        minBidIncreasePercent = _minBidIncreasePercent;
    }

    // @notice allows owner to change the director's reward
    // @param _directorRewardPercent new value
    function setDirectorRewardPercent(uint _directorRewardPercent) external onlyOwner {
        require(!running && _directorRewardPercent + ownerRewardPercent < minBidIncreasePercent);
        directorRewardPercent = _directorRewardPercent;
    }

    // @notice allows owner to change the owner's reward
    // @param _ownerRewardPercent new value
    function setOwnerRewardPercent(uint _ownerRewardPercent) external onlyOwner {
        require(!running && directorRewardPercent + _ownerRewardPercent < minBidIncreasePercent);
        ownerRewardPercent = _ownerRewardPercent;
    }

    // @notice stops the game, and attemps to send all the remaining game balance to the director
    function end() public {

        if(!running || endsAt > block.timestamp)
            revert ToEarlyToEnd(endsAt);

        uint _directorReward = gameBalance;
        uint _currentBid = currentBid;        
        gameBalance = 0;
        currentBid = 0;
        running = false;

        (bool success,) = payable(director).call{value: _directorReward}("");

        if(!success) 
            withdrawable[director] += _directorReward; 
        
        emit GameEnd(gameId, _currentBid, director);

    }

    // @notice initializes a new game
    function _start(uint _bid, address _director) private {
        gameId++;
        running = true;
        emit GameStart(gameId, _bid, _director);
    }

    // @notice used by front-end to process user's bid, automatically triggers end/start if necessary
    function bid() external payable nonReentrant {
        
        uint minimum = minBid();
        if(msg.value == 0 || msg.value < minimum)
            revert InsufficientBid(minimum);

        if(running && endsAt < block.timestamp) end();
        if(!running) _start(msg.value, msg.sender);

        address prevDirector = director;
        uint directorReward =  currentBid * (100 + directorRewardPercent) / 100;
        uint ownerReward = currentBid * ownerRewardPercent / 100;

        director = msg.sender;
        gameBalance += msg.value - directorReward - ownerReward;
        currentBid = msg.value;
        endsAt = block.timestamp + duration;

        if(directorReward > 0){
            (bool success,) = payable(prevDirector).call{value: directorReward}("");
            if(!success) withdrawable[prevDirector] += directorReward;
        }

        if(ownerReward > 0){
            address _owner = owner();
            (bool success,) = payable(_owner).call{value: ownerReward}("");
            if(!success) withdrawable[_owner] += ownerReward;
        }

        emit Bid(gameId, currentBid, director);
    }

    // @notice used to withdraw directly from the contract in case a address.send call failed
    function withdraw() public {
        
        if(withdrawable[msg.sender] == 0)
            revert NothingToWithdraw();

        uint currentBidToWithdraw = withdrawable[msg.sender];
        withdrawable[msg.sender] = 0;
        payable(msg.sender).transfer(currentBidToWithdraw);

    }


}
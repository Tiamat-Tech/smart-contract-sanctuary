// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

/**
  The ETHPool protocol is a simple pool of ETH that can be used to invest in and wait for team rewards.
 */
contract ETHPool is Ownable {

    /**
      The total amount of ETH deposited by each contributor (reward's time-dependent).
     */
    mapping(address => uint256) private _contributions;
    
    /**
      The total amount of ETH in the pool.
     */
    uint256 public totalPool;
    
    /**
      The total amount of ETH deposited by contributor (reward's time-dependent).
     */
    uint256 private _depositorsProportionalPool;

    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event Reward(uint256 amount);

    constructor() {} 
    
    /**
      Allows Team to deposit rewards into the pool.
     */
    function reward() public payable onlyOwner {
        totalPool += msg.value;
        emit Reward(msg.value);
    }
    
    /**
      Allows msg.sender to deposit ETH into the pool.
     */
    function deposit() public payable {
      uint256 proportionalContribution = msg.value;
      if (totalPool > 0) {
        proportionalContribution = msg.value * _depositorsProportionalPool / totalPool;
      }
      
      _contributions[msg.sender] += proportionalContribution;
      _depositorsProportionalPool += proportionalContribution;
      totalPool += msg.value;
      assert(address(this).balance == totalPool);
      emit Deposit(msg.sender, msg.value);
    }
    

    /**
      Allows the msg.sender to withdraw the deposited ETH plus the corresponding rewards (depending on deposits times).
     */
    function withdraw() public {
      uint256 balance = getBalance(msg.sender);
      require(balance > 0, 'You have no balance to withdraw');
      (bool success, ) = msg.sender.call{value: balance}('');
      require(success, 'Could not withdraw');
      emit Withdraw(msg.sender, balance);
    }

    /**
      Returns the deposited ETH by the msg.sender, plus the corresponding rewards (depending on deposits times).
     */
    function getBalance(address user) public view returns (uint256) {
      if(totalPool == 0 || _depositorsProportionalPool == 0) {
        return 0;
      }
      return _contributions[user] * totalPool / _depositorsProportionalPool;
    }
}
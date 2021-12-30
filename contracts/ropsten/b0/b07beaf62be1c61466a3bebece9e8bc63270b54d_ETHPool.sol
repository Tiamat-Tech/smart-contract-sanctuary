// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "hardhat/console.sol";


// NOTE: ETHPool
// NOTE: Based on  https://uploads-ssl.webflow.com/5ad71ffeb79acc67c8bcdaba/5ad8d1193a40977462982470_scalable-reward-distribution-paper.pdf
contract ETHPool {

  //NOTE: Is not defined if there is only one team address or a group, this also can be resolved with "Ownable", as not defined, shortest path.
  address private teamAddress;
   
  uint private T = 0; //T
  uint private S = 0; //S

  mapping (address => uint) private stake; 
  mapping (address => uint) private s0; 

  event Deposit(address indexed _from, uint _value);
  event Withdraw(address indexed _from, uint _value);
  event Distribute(address indexed _from, uint _value);

  //NOTE: Not defined either, in the tests there is specific test to test this feature and fine tune properly if required.
  uint constant percentPrecision = 100;

  // Initial Set. The deployer is the team.
  constructor() {
    teamAddress = msg.sender;
  }
  
  // Rewards distribution
  //NOTE: onlyOwner candidate
  function distribute() payable public {
    require(msg.sender == teamAddress, 'Only the team can Distribute');
    require(T != 0, 'No stakers for distribution');
    S  = S + (msg.value*percentPrecision/T);
    emit Distribute(msg.sender,msg.value);
  }

  // Deposit
  function deposit()  payable public {
    require(msg.sender != teamAddress, 'The team cannot deposit');
    stake[msg.sender] = msg.value;
    s0[msg.sender] = S;
    T = T + msg.value;
    emit Deposit(msg.sender,msg.value);
  }
  
  // Withdraw fund with rewards
  // NOTE: In this context means "Claim ALL"
  // NOTE: Is not defined what to do with remaining Gwei due precision errors.
  // NOTE: https://ethereum.stackexchange.com/questions/19341/address-send-vs-address-transfer-best-practice-usage/38642
  function withdraw() public  {
    uint deposited = stake[msg.sender];
    uint reward = (deposited * (S - s0[msg.sender]))/percentPrecision;
    T = T - deposited;
    stake[msg.sender] = 0;
    uint amountToWithdraw = deposited + reward;
    (bool success, ) = msg.sender.call{value:amountToWithdraw}("");
    require(success, "Transfer failed.");
    emit Withdraw(msg.sender, amountToWithdraw);
  }

  // Total Pool balance
  // NOTE: Keeps the unit for distribution for proportional distribution.
  function getTotalPoolBalance() public view returns (uint){
    return S;
  }
  
  // Total Stake Balance
  // NOTE: All the deposited found will go here.
  function getTotalStakeBalance() public view returns (uint){
    return T;
  }

  // Deposit Stake
  function getDepositStake() public view returns (uint){
    return stake[msg.sender];
  }
  
}
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  mapping(address => uint256) public balances;
  uint256 public totalStaked;

  uint256 public constant threshold = 100 ether;
  uint256 public deadline = block.timestamp + 2 days;
  bool public openForWithdraw = false;

  event Stake(address indexed staker, uint256 amount);
  

  ExampleExternalContract public exampleExternalContract;

  constructor(address exampleExternalContractAddress) public {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
  //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
  function stake() public payable beforeDeadline {
      balances[msg.sender] += msg.value;
      emit Stake(msg.sender, msg.value);
      totalStaked += msg.value;
  }


  // After some `deadline` allow anyone to call an `execute()` function
  //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
  function execute() public notCompleted {
      require(block.timestamp >= deadline, "deadline has not been reached");
      if (address(this).balance < threshold) {
          openForWithdraw = true;
      } else {
        exampleExternalContract.complete{value: address(this).balance}();
      }

  }

  // if the `threshold` was not met, allow everyone to call a `withdraw()` function
  function withdraw(address payable _to) public notCompleted {
      require(openForWithdraw, "withdrawals are not open");
      _to.transfer(balances[msg.sender]);
      delete balances[msg.sender];
  }


  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  function timeLeft() public view returns (uint256) {
      if (deadline <= block.timestamp) {
          return 0;
      }
      return deadline - block.timestamp;

  }

  // Add the `receive()` special function that receives eth and calls stake()
  receive() external payable {
      stake();
  }

  // require thestake period to be active
  modifier beforeDeadline() {
      require(deadline >= block.timestamp, "stake period has ended");
      _;
  }


  modifier notCompleted() {
      require(exampleExternalContract.completed() == false, "already completed");
      _;
  }


}
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ETHPool is AccessControl {
    event Deposit(address indexed _address, uint256 _value);
    event Withdraw(address indexed _address, uint256 _value);

    bytes32 public constant TEAM_MEMBER_ROLE = keccak256("TEAM_MEMBER_ROLE");

    uint256 public total;
  
    address[] public users;
      
    struct DepositValue {
        uint256 value;
        bool hasValue;
    }

    mapping(address => DepositValue) public deposits;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TEAM_MEMBER_ROLE, msg.sender);
    }

    receive() external payable {
                
        if(!deposits[msg.sender].hasValue) // only pushes new users
            users.push(msg.sender);

        deposits[msg.sender].value += msg.value;
        deposits[msg.sender].hasValue = true;

        total += msg.value;
        console.log("receive()", msg.value);
        console.log("total after received", total);
        emit Deposit(msg.sender, msg.value);
    }
    
    function depositRewards() public payable onlyRole(TEAM_MEMBER_ROLE) {
        require(total > 0); // No rewards to distribute if the pool is empty.
        console.log(" ---  start depositRewords", msg.value);

        for (uint i = 0; i < users.length; i++){
            
           address user = users[i];

           uint rewards = ((deposits[user].value * msg.value) / total);

           deposits[user].value += rewards;
           console.log("-- >> new deposits[user].value", deposits[user].value);
        }
       console.log(" ---  start depositRewords, old total = ", total); 
       total += msg.value;
       console.log(" ---  start depositRewords, new total = ", total); 

    }

    function withdraw() public {
        uint256 deposit = deposits[msg.sender].value;
        require(deposit > 0, "You don't have anything left to withdraw");

        console.log("withdraw" ,  deposit);
        console.log("total was:", total);
        
        deposits[msg.sender].value = 0;
        (bool success, ) = msg.sender.call{value:deposit}("");
  
        require(success, "Transfer failed");
        require( total >= deposit, "total is smaller than deposit when withdraw");
        unchecked { total -= deposit; }
        console.log("total after withdraw", total);
        emit Withdraw(msg.sender, deposit);
    }

    function addTeamMember(address account) public {
        grantRole(TEAM_MEMBER_ROLE, account);
    }

    function removeTeamMember(address account) public {
        revokeRole(TEAM_MEMBER_ROLE, account);
    }
}
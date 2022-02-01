pragma solidity ^0.8.0;

/* Deposit Rewards (managing the team member) */
/* Deposit Rewards by team */
/* use oppen zeppelin access control it support team Roles */

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ETHPool is AccessControl {
    event Deposit(address indexed _address, uint256 _value);
    event Withdraw(address indexed _address, uint256 _value);

    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");
 
   /* Receive Method */

    uint256 public total;
  
    address[] public users;
      
    struct DepositValue  {
        uint256 value;
        bool hasValue;
        uint256 reward;
    }

    mapping(address => DepositValue) public deposits;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TEAM_ROLE, msg.sender);
    }

    receive() external payable {
           /* new users */     
        if(!deposits[msg.sender].hasValue) 
            users.push(msg.sender);
        deposits[msg.sender].value += msg.value;
        deposits[msg.sender].hasValue = true;

        total += msg.value;

        emit Deposit(msg.sender, msg.value);
    }
    
      /* deposit Rewards Method */
      /* No rewards in pool */

    function depositRewards() public payable onlyRole(TEAM_ROLE) {
        require(total > 0); 

        for (uint i = 0; i < users.length; i++){
            
           address user = users[i];

           uint rewards = ((deposits[user].value * msg.value) / total);

           deposits[user].reward += rewards;
           total+=rewards;
        }
    }

    /* withdraw Method */

    function withdraw() public {
        uint256 deposit = deposits[msg.sender].value;
        uint256 rewardval = deposits[msg.sender].reward;
        require(deposit > 0, "don't have withdraws");
        
        deposits[msg.sender].value = 0;
        deposits[msg.sender].reward=0;
        (bool success, ) = msg.sender.call{value:deposit}("");
         total-=(deposit+rewardval);
        require(success, "Transfer failed");
        
        emit Withdraw(msg.sender, (deposit+rewardval));
    }

    function addTeam(address account) public {
        grantRole(TEAM_ROLE, account);
    }

    function removeTeam(address account) public {
        revokeRole(TEAM_ROLE, account);
    }
}
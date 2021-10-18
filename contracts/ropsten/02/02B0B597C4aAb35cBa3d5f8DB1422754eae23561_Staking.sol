//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is ReentrancyGuard {
   using SafeMath for uint256;

   //Stores address for l4inv token
   address public tokenAddress;

   //Stores each users balance
   mapping(address => uint256) private balances;

   constructor(address _tokenAddress){
       tokenAddress = _tokenAddress;
   }

   event Deposit(address indexed user, uint256 indexed amount);
   event Withdraw(address indexed user, uint256 indexed amount);

   function deposit(uint256 amount) public nonReentrant {
       require(amount > 0, "Staking amount must be > 0");

       IERC20 token = IERC20(tokenAddress);  
       uint256 allowance = token.allowance(msg.sender, address(this));
       require(allowance >= amount, "Staking allowance too small");

       token.transferFrom(msg.sender, address(this), amount);

       balances[msg.sender] = balances[msg.sender].add(amount);

       emit Deposit(msg.sender, amount); 
   }
   
    function balanceOf(address user) public view returns (uint256) {
        return balances[user];
    }
}
/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

pragma solidity ^0.5.0;

contract test {
   mapping(address => uint) public balances;

   function updateBalance(address reciever,uint newBalance) external {
      balances[reciever] = newBalance;
   }
   
}

contract Updater{
   function updateBalance(uint input) public returns (uint) {
      test ledgerBalance = new test();
      ledgerBalance.updateBalance(msg.sender,input);
      return ledgerBalance.balances(msg.sender);
   }
   function checkBalance(address input) external returns(uint){
       test ledgerBalance = new test();
      return ledgerBalance.balances(input);
      
   }
}
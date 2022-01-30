/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

contract Lottery {
   address public manager;
   address[] public players;

   constructor() {
       manager = msg.sender;
   }

   function enter() public payable {
       require(msg.value > .01 ether);
       players.push(msg.sender); 
   }

   function random() private view returns (uint) {
        uint source = block.difficulty + block.timestamp;
        return uint(keccak256(abi.encode(source)));
   }

   function pickWinner() public restricted {
       uint index = random() % players.length;
       payable(players[index]).transfer(address(this).balance);
       players = new address[](0);
   }

   function getPlayers() public view returns (address[] memory) {
       return players;
   }

   modifier restricted() {
       require(msg.sender == manager);
       _;
   }
}
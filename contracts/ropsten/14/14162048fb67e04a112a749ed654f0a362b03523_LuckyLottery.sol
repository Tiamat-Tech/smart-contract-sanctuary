/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract LuckyLottery{

    address payable[] public players;
    address payable public admin;
    // msg.sender is the public key or address of the person that deployed the contract
    constructor(){

        admin = payable(msg.sender);   
    }

    receive() external payable{
        require(msg.value == 1 ether , "Must be exactly 1 ether");

        require(msg.sender != admin , "Admin cannot play this lottery");

        players.push(payable(msg.sender));
        
    }



    function getBalance() public view returns(uint){
        return address(this).balance; // returns the contracts balance
    }


    function random() internal view returns(uint){
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, players.length)));
    }

    function pickWinner() public {
        require(admin == msg.sender , "YOu are not the owner");
        require(players.length >= 3, "Not enough players have entered the game");

        address payable winner;

        winner = players[random() % players.length]; 

        winner.transfer(getBalance());

        players = new address payable[](0);

    }

}
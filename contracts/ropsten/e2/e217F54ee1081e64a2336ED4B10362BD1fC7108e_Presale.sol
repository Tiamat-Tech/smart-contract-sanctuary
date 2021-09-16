// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./TestToken.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Presale is Pausable,Ownable{

    uint256 public weiRaised;

    uint256 public cap;
    uint256 public minInvestment;
    uint256 public rate = 500 ether;
    bool public isFinalized;

    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);
    event Finalized();


    function buyToken() payable public{
        TestToken token = TestToken(0x49b83FE397ad2523Fdd332264AdED0253c9e1720);
        uint256 amountTobuy = msg.value * rate;
        uint256 dexBalance = token.balanceOf(address(this));
        require(amountTobuy > 0, "You need to send some ether");
        require(amountTobuy <= dexBalance, "Not enough tokens in the reserve");
        token.transfer(msg.sender, amountTobuy);
        emit TokenPurchase(msg.sender, msg.value, amountTobuy);
    }

    


}
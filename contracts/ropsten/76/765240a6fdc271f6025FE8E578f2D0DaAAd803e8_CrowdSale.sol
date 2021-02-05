// contracts/TheHealYouToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract CrowdSale is Ownable {
    using SafeMath for uint256;

    // The token being sold
    ERC20 public token;

    // start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    // address where funds are collected
    address payable public wallet;

    // how many token units a buyer gets per wei
    uint256 public rate;

    // amount of raised money in wei
    uint256 public weiRaised;

    /**
     * event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


    constructor(uint256 _startTime, uint256 _endTime, uint256 _rate, address payable _wallet, address _token) public {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_rate > 0);
        require(_wallet != address(0));

        token = ERC20(_token);
        startTime = _startTime;
        endTime = _endTime;
        rate = _rate;
        wallet = _wallet;
    }

    // fallback function can be used to buy tokens
    receive() payable external {
        buyTokens(msg.sender);
    }

    // low level token purchase function
    function buyTokens(address beneficiary) public payable {
        require(beneficiary != address(0), "0 address error");
        require(validPurchase(), "Invalid purchase");

        uint256 weiAmount = msg.value;

        // calculate token amount to be created
        uint256 tokens = weiAmount.mul(rate).div(10**10);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        token.transfer(beneficiary, tokens);
        emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);

        forwardFunds();
    }

    // send ether to the fund collection wallet
    // override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    // @return true if the transaction can buy tokens
    function validPurchase() internal view returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        return withinPeriod && nonZeroPurchase;
    }

    // @return true if crowdSale event has ended
    function hasEnded() public view returns (bool) {
        return now > endTime;
    }

    // change rate only via owner
    function setRate(uint256 _rate) external onlyOwner {
        rate = _rate;
    }

    // change startTime only via owner
    function setStartTime(uint256 _startTime) external onlyOwner {
        startTime = _startTime;
    }

    // change endTime only via owner
    function setEndTime(uint256 _endTime) external onlyOwner {
        endTime = _endTime;
    }

    // change wallet address only via owner
    function setWallet(address payable _wallet) external onlyOwner {
        wallet = _wallet;
    }

    // withdraw tokens in case of emergency
    function withdrawTokens(uint256 tokens) external onlyOwner {
        token.transfer(msg.sender, tokens);
    }


}
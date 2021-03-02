//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./DappToken.sol";
import "./DaiToken.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 

contract TokenFarm is Ownable {
    using SafeMath for uint;
    
    string public name = "Dapp Token Farm";
    DappToken public dappToken;
    DaiToken public daiToken;

    address[] public stakers;
    mapping(address => uint) public stakingBalance;
    mapping(address => bool) public hasStaked;
    mapping(address => bool) public isStaking;

    constructor(DappToken _dappToken, DaiToken _daiToken) {
        dappToken = _dappToken;
        daiToken = _daiToken;
    }

    //1. Stakes Tokens(Deposit)
    function stakeTokens(uint _amount) public {

        require(_amount > 0, "can't stake 0 tokens");        
        //Transfer Mock Dai tokens to this contract for staking
        //has to use transferFrom instead of transfer because the contract address is calling transfer instead of the investor
        daiToken.transferFrom(msg.sender, address(this), _amount);

        //Update staking balance
        stakingBalance[msg.sender] = stakingBalance[msg.sender].add(_amount);

        //Add stakers only if they haven't staked already
        if (!hasStaked[msg.sender]) {
            stakers.push(msg.sender);
            hasStaked[msg.sender] = true;
        }
        isStaking[msg.sender] = true;

    }
    //Unstaking Tokens(Withdraw)
    function unstakeTokens(uint _amount) public {
        uint balance = stakingBalance[msg.sender];
        require(_amount > 0 && balance > 0, "can't withdraw 0 tokens");
        daiToken.transfer(msg.sender, _amount);
        stakingBalance[msg.sender] = balance.sub(_amount);
        if (stakingBalance[msg.sender] == 0) {
            isStaking[msg.sender] = false;
        }

    }
    //Issuing Tokens
    function issueTokens() public onlyOwner {
        for (uint i = 0; i < stakers.length; i=i.add(1)) {
            address recipient = stakers[i];
            uint balance = stakingBalance[recipient];
            if (balance > 0)
            dappToken.transfer(recipient, balance);
        }
    }
}
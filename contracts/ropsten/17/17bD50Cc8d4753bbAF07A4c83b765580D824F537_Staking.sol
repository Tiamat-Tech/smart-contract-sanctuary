// SPDX-License-Identifier: UNLICENSED

// Code by zipzinger and cmtzco
// DEFIBOYS
// defiboys.com

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./StakingNft.sol";

contract Staking is Ownable {

    IERC20 private _token;
    uint256 public rewardRate = 10;
    mapping(address => bool) staked;
    mapping(address => uint256) stakedAmount;
    mapping(address => uint256) lastTxnBlock;
    mapping(address => uint256) spentAmount;
    mapping(address => uint256) summarizedReward;

    event StakedTokens(address from);
    event UnstakedTokens(address from);

    constructor (IERC20 token) {
        _token = token;
    }

    function setStakeToken(IERC20 token) public onlyOwner {
        _token = token;
    }

    function getStakeToken() public view returns (IERC20) {
        return _token;
    }

    function getStakedAmount(address _addr) public view returns (uint256) {
        return stakedAmount[_addr];
    }

    function setRewardRate(uint256 _newRate) public onlyOwner {
        require(_newRate > 0, "rewardRate must be greater than zero");
        rewardRate = _newRate;
    }

    function testStake(uint256 _num) public onlyOwner {
        staked[msg.sender] = true;
        stakedAmount[msg.sender] = _num;
        lastTxnBlock[msg.sender] = block.number;
        spentAmount[msg.sender] = 0;
        summarizedReward[msg.sender] = 0;
    }

    function testAddStake(uint256 _num) public onlyOwner {
        require(staked[msg.sender], "Run testStake() first");
        summarizedReward[msg.sender] = SafeMath.add(summarizedReward[msg.sender], rewardBalance(payable(msg.sender)));
        spentAmount[msg.sender] = 0;
        stakedAmount[msg.sender] = SafeMath.add(stakedAmount[msg.sender], _num);
        lastTxnBlock[msg.sender] = block.number;
    }

    function rewardBalance(address payable _addr) public view returns (uint256) {
        uint256 blockdiff = SafeMath.sub(block.number, lastTxnBlock[_addr]);
        uint256 inner = SafeMath.mul(rewardRate, SafeMath.mul(stakedAmount[_addr], blockdiff));
        uint256 result = SafeMath.add(summarizedReward[_addr], SafeMath.sub(inner, spentAmount[_addr]));
        return result;
    }

    function stake(uint256 _amount) public {
        address from = msg.sender;
        require(_token.balanceOf(from) >= _amount, "You dont own that amount of tokens");

        _token.transferFrom(from, address(this), _amount);

        if (!staked[from]) {
            staked[from] = true;
            stakedAmount[from] = _amount;
            lastTxnBlock[from] = block.number;
            spentAmount[from] = 0;
            summarizedReward[from] = 0;
        } else {
            summarizedReward[from] = SafeMath.add(summarizedReward[from], rewardBalance(payable(from)));
            spentAmount[from] = 0;
            stakedAmount[from] = SafeMath.add(stakedAmount[from], _amount);
            lastTxnBlock[from] = block.number;
        }
        emit StakedTokens(from);
    }

    function unstake(uint256 _amount) public {
        address from = msg.sender;
        require(stakedAmount[from] >= _amount, "You dont own that amount of tokens");
        _token.transfer(from, _amount);

        summarizedReward[from] = SafeMath.add(summarizedReward[from], rewardBalance(payable(from)));
        spentAmount[from] = 0;
        stakedAmount[from] = SafeMath.sub(stakedAmount[from], _amount);
        lastTxnBlock[from] = block.number;

        emit UnstakedTokens(from);
    }

    function buyNft(address _addr) public {
        uint256 tokenPrice = StakingNft(_addr).currentPrice();
        require(rewardBalance(payable(msg.sender)) >= tokenPrice, "Not enough Reward token for purchase");
        spentAmount[msg.sender] += tokenPrice;
        StakingNft(_addr).mintToAddress(msg.sender);
    }

}
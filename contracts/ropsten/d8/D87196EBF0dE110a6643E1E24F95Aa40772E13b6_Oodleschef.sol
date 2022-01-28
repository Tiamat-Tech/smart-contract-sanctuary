//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './IOodleschef.sol';



contract Oodleschef is IOodleschef{

    using SafeMath for uint256;

    IERC20 tokenA;

    struct stakeHolder {
		bool isPreviousHolder;
		uint256 stakedCoins;
		uint256 rewards;
		bool isActive;
	}
    /*
        Events to be used in Contract
    */

    event deposited(address sender, uint256 amount);
    event Withdraw(address reciever, uint256 amount);


/*
    State Variable to store informatino about all stake holders in oodleschef.sol
    @totalStakedCoins -> total supply of staked coins
    @owner -> address that deployed this contract
    @stakeHolders -> mapping to store all of the stakeholder data against there address
    @stakeHolderArray -> address of all the stake holder till now;
*/
    uint256 public totalStakedCoins;
    uint256 public totalRewardCollected;
	address public owner;
	mapping(address => stakeHolder) public stakeHolders;
	address[] public stakeHolderArray;

    constructor(address _tokenA){
        tokenA =  IERC20(_tokenA);
        owner = msg.sender;
    }

    function addStakeHolder(address onBehalfOf, stakeHolder memory holder) internal {
        stakeHolderArray.push(onBehalfOf);
        stakeHolders[onBehalfOf] = holder;
    }

    function deposit(address onBehalfOf, uint256 amount) external override {

        stakeHolder storage holder  = stakeHolders[onBehalfOf];

        require(onBehalfOf == msg.sender, 'Oodleschef : Not the owner of account you want to add');
        
        IERC20 _tokenA = tokenA;

        _tokenA.transferFrom(onBehalfOf,address(this), amount);
        //Fee for each deposit is decided to be 5 percent for each transaction.
        uint256 calculateFee = amount.mul(5).div(100);

        
        amount -= calculateFee;
        
        totalStakedCoins += amount;
        totalRewardCollected += calculateFee;

        if(!(holder.isPreviousHolder)){
            
            addStakeHolder( onBehalfOf,
                stakeHolder({
                    isPreviousHolder: true,
                    stakedCoins: amount,
                    rewards: 0,
                    isActive :true
                })
            );
        }
        else {
            holder.stakedCoins += amount;
        }

        emit deposited(onBehalfOf, amount);
    }

/* this function calculate percentage to distribute reward according to stakedCoins
    @staked
 */

    function CalculatePercentage(uint256 stakedCoins)internal view returns(uint256){
        uint256 percentOfRewards = stakedCoins.mul(100).div(totalStakedCoins);
        return percentOfRewards;
    }

    function withdraw(address holder) external override {
        
        stakeHolder storage _holder = stakeHolders[holder];

        require(_holder.isActive == true, 'Oodleschef: No stakes of given address found');

        uint256 amount = CalculatePercentage(_holder.stakedCoins).mul(totalRewardCollected).div(100);
        
        totalStakedCoins -= _holder.stakedCoins;
        totalRewardCollected -= amount; 

        amount += _holder.stakedCoins;
        
        tokenA.transfer(holder,amount);

        delete stakeHolders[holder];

        emit Withdraw(holder, _holder.stakedCoins);
        
    }

    function withdrawExactAmountofStake(address holder, uint256 amount) external override{
        stakeHolder storage Holder = stakeHolders[holder];
        stakeHolder memory _holder = Holder;

        require(_holder.isActive == true, 'Oodleschef: No stake of given address Found');
        require(amount < _holder.stakedCoins,'Oodleschef: not much staked coins available');

        uint256 _amount = CalculatePercentage(amount).mul(totalRewardCollected).div(100);
        
        totalStakedCoins -= amount;
        totalRewardCollected -= _amount;
        _amount += amount;

        Holder.stakedCoins -= amount;
        
        tokenA.transfer(holder,_amount);
        emit Withdraw(holder, _holder.stakedCoins);
    }


}
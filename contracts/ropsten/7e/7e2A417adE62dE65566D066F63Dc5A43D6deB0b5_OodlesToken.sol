//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';


contract OodlesToken is ERC20{
	
	using SafeMath for uint256;
	
	struct stakeHolder {
		bool isPreviousHolder;
		uint256 stakedCoins;
		uint256 rewards;
		bool isActive;
	}

	uint256 totalStakedCoins;
	address public owner;
	mapping(address => stakeHolder) stakeHolders;
	address[] public stakeHolderArray;

	// uint256 constant TRANSFER_FEE_PERCENT = 500;

	event AddStakeHolder (address holder, uint256 amount);

	constructor() ERC20("OodlesToken", "OTK") {
		_mint(msg.sender, 100000 * (10 ** uint(decimals())));
		owner = msg.sender;
		totalStakedCoins = 0;
	}

	

	function addStakeHolder(address holder, uint256 amount) external returns(bool){
		
		require(balanceOf(holder) >= amount, "Oodles Protocol: Insufficient Balance");

		stakeHolder memory _holder;
		if(!(stakeHolders[holder].isPreviousHolder)){
			
			stakeHolderArray.push(holder);
		} 
		
		totalStakedCoins += amount;
		
		_holder.stakedCoins = amount;
		_holder.isPreviousHolder = true;
		_holder.rewards = 0;
		_holder.isActive = true;
		stakeHolders[holder] = _holder;

		_transfer(msg.sender, address(this), amount);
		return true;
	}


	function removeStakeHolder(address holder) external returns (bool){
		
		stakeHolder memory _holder = stakeHolders[holder];
		
		require(_holder.isActive == true, "Oodles Protocol: Doesn't have A stake");
		
		ERC20(address(this)).transfer(msg.sender,_holder.stakedCoins.add(_holder.rewards));
		
		totalStakedCoins -= _holder.stakedCoins;

		stakeHolders[holder].stakedCoins = 0;
		stakeHolders[holder].rewards =0;
		stakeHolders[holder].isActive = false;
		
	}

	function distributeFee (uint fee,address recipient) internal returns(bool){
		
		uint256 NumberOfStakeHolder = stakeHolderArray.length;
		uint256  _totalStakedCoins = totalStakedCoins;


		for(uint i = 0; i< NumberOfStakeHolder; i++){
			stakeHolder memory holder = stakeHolders[stakeHolderArray[i]];

			uint256 value = holder.stakedCoins.mul(100).div(_totalStakedCoins);

			stakeHolders[stakeHolderArray[i]].rewards += fee.mul(value).div(100);

		}
	}
	function transfer(address recipient, uint256 amount) public virtual override(ERC20) returns(bool) {
		
		uint256 fee =  amount.mul(5).div(100);

		_transfer(msg.sender,recipient, amount - fee);
		_transfer(msg.sender,address(this),fee);

		distributeFee(fee, msg.sender);
		return true;
	}
}
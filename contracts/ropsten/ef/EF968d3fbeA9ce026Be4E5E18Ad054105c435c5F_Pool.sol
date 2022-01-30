//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import "IERC20.sol";

interface ERC20 {
	function balanceOf(address owner) external view returns (uint);
	function allowance(address owner, address spender) external view returns (uint);
	function approve(address spender, uint value) external returns (bool);
	function transfer(address to, uint value) external returns (bool);
	function transferFrom(address from, address to, uint value) external returns (bool); 
}

contract Pool {


	address nitroOperatorAddress = 0x733990D97D7c5237FFE92A98d729b6dfba72D656; // TODO Change this to a permenant address // The address to recieve nitro funds too
	bool public isPaused = false; // -> require(!paused, "the contract is paused");
	uint nitroServiceFee = 10; // How much we charge LPs one profits as percentag

	struct pool {
		bool doesExist; // Check pool exists
		uint[] updatedTime; // A record of the pool transactions over time, this is updated when everything else is
		uint[] poolDepositedLiquidity; // The total liquidity deposited in the pool, before profit or loss
		uint[] poolTotalLiquidity; // The total liquidity in the pool, after profit or loss
		mapping(address => uint) userDepositedLiquidity; // The amount deposited by LP in the pool, before profit or loss
	}

	mapping(address => pool) internal pools; // Token address

	function addLiquidity(address _owner, address _token, uint _amount) public {

		ERC20(_token).transferFrom(_owner, address(this), _amount); // transfer the tokens from the sender to this contract

		require(!isPaused, "The contract is paused"); // Require the contract is not paused

		/*
		pools[_token].doesExist = true; // Confirm pool exists
		pools[_token].updatedTime.push(block.timestamp); // Push timestamp of update
		pools[_token].poolDepositedLiquidity.push(pools[_token].poolDepositedLiquidity[pools[_token].poolDepositedLiquidity.length] + msg.value); // Update deposited pool
		pools[_token].poolTotalLiquidity.push(pools[_token].poolTotalLiquidity[pools[_token].poolTotalLiquidity.length] + msg.value); // Update total pool
		pools[_token].userDepositedLiquidity[msg.sender] += msg.value; // Updated user deposited
		*/

	}

	/*
	function withdrawLiquidity(address _token) public payable {

		uint userTotalLiquidity = calculateLpInterest(_token, msg.sender); // Calculate how much money the liquidity provider is owed
		uint userDepositedLiquidity = pools[_token].userDepositedLiquidity[msg.sender];
		pools[_token].updatedTime.push(block.timestamp); // Push timestamp of update
		pools[_token].poolDepositedLiquidity.push(pools[_token].poolDepositedLiquidity[pools[_token].poolDepositedLiquidity.length] - pools[_token].userDepositedLiquidity[msg.sender]); // Update deposited pool
		pools[_token].poolTotalLiquidity.push(pools[_token].poolTotalLiquidity[pools[_token].poolTotalLiquidity.length] - userTotalLiquidity); // Update total pool
		pools[_token].userDepositedLiquidity[msg.sender] = 0; // Reset user deposit

		if (userTotalLiquidity > userDepositedLiquidity) {

			// Subtract value of nitroServiceFee as percentage
			// IERC20(_token).transfer(msg.sender, userTotalLiquidity);

		}

		IERC20(_token).transfer(msg.sender, userTotalLiquidity);

	}
	*/

	function simulateLoosingTrade(address _owner, address _token, uint _amount) public {

		ERC20(_token).transferFrom(_owner, address(this), _amount); // transfer the tokens from the sender to this contract

		// require(pools[_token].doesExist, "No liquidity pool");

	}

	function calculateLpInterest(address _token, address _userAddress) public view returns (uint userTotalLiquidity) {

		uint poolDepositedLiquidity = pools[_token].poolDepositedLiquidity[pools[_token].poolDepositedLiquidity.length]; // The amount of money deposited in the pool
		uint userDepositedLiquidity = pools[_token].userDepositedLiquidity[_userAddress]; // The amount the LP has deposited
		uint userPoolShare = (userDepositedLiquidity / poolDepositedLiquidity) * 100;
		uint poolTotalLiquidity = pools[_token].poolTotalLiquidity[pools[_token].poolTotalLiquidity.length]; // The actual balance of the liquidity pool
		return (poolTotalLiquidity / 100) * userPoolShare; // Return their share of the pool

	}

}
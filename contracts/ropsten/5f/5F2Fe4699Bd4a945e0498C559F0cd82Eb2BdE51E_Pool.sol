//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.0;

import "ERC20.sol";

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

	function addLiquidity(address _tokenAddress, uint _tokenAmount) public payable {

		require(!isPaused, "The contract is paused"); // Require the contract is not paused

		pools[_tokenAddress].doesExist = true; // Confirm pool exists
		pools[_tokenAddress].updatedTime.push(block.timestamp); // Push timestamp of update
		pools[_tokenAddress].poolDepositedLiquidity.push(pools[_tokenAddress].poolDepositedLiquidity[pools[_tokenAddress].poolDepositedLiquidity.length] + msg.value); // Update deposited pool
		pools[_tokenAddress].poolTotalLiquidity.push(pools[_tokenAddress].poolTotalLiquidity[pools[_tokenAddress].poolTotalLiquidity.length] + msg.value); // Update total pool
		pools[_tokenAddress].userDepositedLiquidity[msg.sender] += msg.value; // Updated user deposited

		ERC20(_tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount); // transfer the tokens from the sender to this contract

	}

	function withdrawLiquidity(address _tokenAddress) public payable {

		uint userTotalLiquidity = calculateLpInterest(_tokenAddress, msg.sender); // Calculate how much money the liquidity provider is owed
		uint userDepositedLiquidity = pools[_tokenAddress].userDepositedLiquidity[msg.sender];
		pools[_tokenAddress].updatedTime.push(block.timestamp); // Push timestamp of update
		pools[_tokenAddress].poolDepositedLiquidity.push(pools[_tokenAddress].poolDepositedLiquidity[pools[_tokenAddress].poolDepositedLiquidity.length] - pools[_tokenAddress].userDepositedLiquidity[msg.sender]); // Update deposited pool
		pools[_tokenAddress].poolTotalLiquidity.push(pools[_tokenAddress].poolTotalLiquidity[pools[_tokenAddress].poolTotalLiquidity.length] - userTotalLiquidity); // Update total pool
		pools[_tokenAddress].userDepositedLiquidity[msg.sender] = 0; // Reset user deposit

		if (userTotalLiquidity > userDepositedLiquidity) {

			// Subtract value of nitroServiceFee as percentage
			// ERC20(_tokenAddress).transfer(msg.sender, userTotalLiquidity);

		}

		ERC20(_tokenAddress).transfer(msg.sender, userTotalLiquidity);

	}

	function simulateLoosingTrade(address _tokenAddress, uint _tokenAmount) public payable {

		require(pools[_tokenAddress].doesExist, "No liquidity pool");

		ERC20(_tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount); // transfer the tokens from the sender to this contract

	}

	function calculateLpInterest(address _tokenAddress, address _userAddress) public view returns (uint userTotalLiquidity) {

		uint poolDepositedLiquidity = pools[_tokenAddress].poolDepositedLiquidity[pools[_tokenAddress].poolDepositedLiquidity.length]; // The amount of money deposited in the pool
		uint userDepositedLiquidity = pools[_tokenAddress].userDepositedLiquidity[_userAddress]; // The amount the LP has deposited
		uint userPoolShare = (userDepositedLiquidity / poolDepositedLiquidity) * 100;
		uint poolTotalLiquidity = pools[_tokenAddress].poolTotalLiquidity[pools[_tokenAddress].poolTotalLiquidity.length]; // The actual balance of the liquidity pool
		return (poolTotalLiquidity / 100) * userPoolShare; // Return their share of the pool

	}

}
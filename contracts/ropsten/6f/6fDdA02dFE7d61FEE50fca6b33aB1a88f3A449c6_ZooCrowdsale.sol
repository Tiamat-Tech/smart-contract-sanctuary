pragma solidity ^0.7.5;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ZooCrowdsale is Ownable 
{
	IERC20 public zoo;
	IERC20 public dai;
	
	uint256 public crowdsaleStart;
	uint256 public crowdsaleDuration;
	address public team;

	uint256 public saleLimit = 800 * 10 ** 18;
	uint256 public zooRate = 5;
	
	mapping (address => uint256) public amountAllowed;

	constructor (address _zoo, address _dai, address _team, uint256 _duration) {

		zoo = IERC20(_zoo);
		dai = IERC20(_dai);

		team = _team;
		crowdsaleStart = block.timestamp;
		crowdsaleDuration = _duration;
	}

	/// @notice Function to buy zoo tokens for dai.
	/// @notice get x5 Zoo of dai spent.
	/// @param amount - amount of dai spent.
	function spentDaiforZoo(uint256 amount) external
	{
		require(amountAllowed[msg.sender] >= amount, "amount exceeds limit"); // Requires allowed amount left to spent.
		require(block.timestamp <= crowdsaleStart + crowdsaleDuration, "Crowdsale has ended"); // Crowdsale lasts 5 days.

		uint256 zooToBuy = amount * zooRate;           // Get x5 zoo from dai spent.

		dai.transferFrom(msg.sender, team, amount);    // Dai transfers from msg.sender to zoo team address.
		zoo.transfer(msg.sender, zooToBuy);            // Zoo transfers from this contract to msg.sender.

		amountAllowed[msg.sender] -= amount;           // Decreses amount of allowed dai spent.
	}

	/// @notice Function to see price rate of zoo.
	function rate(uint256 amount) public view returns(uint256 zooToBuy)
	{
		zooToBuy = amount * zooRate;
	}

	function batchAddToWhiteList(address[] memory users) external onlyOwner {
		for (uint i = 0; i < users.length; i++) {
			amountAllowed[users[i]] = saleLimit;
		}
	}

	/// @notice Function to add address to whitelist
	/// @notice not the boolean, but adds amount of dai allowed to spent instead.
	/// @notice so, u can spend up to saleLimit with more than 1 transaction.
	function addToWhitelist(address participant) external onlyOwner
	{
		amountAllowed[participant] += saleLimit;
	}
}
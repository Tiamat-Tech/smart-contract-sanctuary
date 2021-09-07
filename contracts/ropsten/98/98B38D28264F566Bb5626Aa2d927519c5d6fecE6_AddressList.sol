pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";

contract AddressList is Ownable
{

	mapping (address => bool) public inList;						// Records address to list.
	
	/// @notice Event records address added to list.
	event AddedToList(address account);

	/// @notice Event records address removed from list.
	event RemovedFromList(address account);

	/// @notice contract constructor.
	constructor() Ownable()
	{

	}

	/// @notice Function to add to list.
	/// @param account - address to add to list.
	function addToList(address account) onlyOwner() public returns (bool isAdded)
	{
		inList[account] = true;
		isAdded = true;

		emit AddedToList(account);								// Records account to event.
	}

	/// @notice Function to remove from no list.
	/// @param account - address to remove from list.
	function removeFromList(address account) onlyOwner() public returns (bool isRemoved)
	{
		inList[account] = false;
		isRemoved = true;
		
		emit RemovedFromList(account);							// Records account to event.
	} 
}
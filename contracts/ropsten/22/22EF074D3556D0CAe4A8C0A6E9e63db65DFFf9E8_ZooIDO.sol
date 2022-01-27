pragma solidity ^0.7.5;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract ZooIDO is Ownable 
{
	using SafeMath for uint256;

	IERC20 public zoo;                                                          // Zoo token.
	IERC20 public dai;                                                          // Dai token.

	address public team;                                                        // Zoodao team address.

	uint256 public idoStart;                                                    // Start date of Ido.
	uint256 public whitelistPhase = idoStart + 5 days;                          // End date of whitelisted buy phase.
	uint256 public idoEnd = whitelistPhase + 3 days;                            // End date of IDO.
	uint256 public claimDate = whitelistPhase + 20 days;                        // Date of claim.

	uint256 public saleLimit = 800 * 10 ** 18;                                  // Amount of dai allowed to spend.
	uint256 public zooRate = 5;                                                 // Rate of zoo for dai.
	uint256 public zooAllocatedTotal;                                           // Amount of total allocated zoo.
	
	mapping (address => uint256) public amountAllowed;                          // Amount of dai allowed to spend for each whitelisted person.

	mapping (address => uint256) public zooAllocated;                           // Amount of zoo allocated for each person.

	mapping (address => bool) public partTaken;                                 // Records if user already take part in not whitelisted IDO.

	event daiInvested(uint256 indexed daiAmount);                               // Records amount of dai spent.

	event zooClaimed(uint256 indexed zooAmount);                                // Records amount of zoo claimed.

	event teamClaimed(uint256 indexed daiAmount, uint256 indexed zooAmount);    // Records amount of dai and zoo claimed by team.

	/// @notice Contract constructor.
	/// @param _zoo - address of zoo token.
	/// @param _dai - address of dai token.
	/// @param _team - address of team.
	/// @param _idoStart - date of start.
	constructor (address _zoo, address _dai, address _team, uint256 _idoStart) {

		zoo = IERC20(_zoo);
		dai = IERC20(_dai);

		team = _team;
		idoStart = _idoStart;
	}

	/// @notice Function to add addresses to whitelist
	/// @notice sets amount of dai allowed to spent.
	/// @notice so, u can spend up to saleLimit with more than 1 transaction.
	function batchAddToWhiteList(address[] calldata users) external onlyOwner {
		for (uint i = 0; i < users.length; i++) {
			amountAllowed[users[i]] = saleLimit;
		}
	}

	/// @notice Function to buy zoo tokens for dai.
	/// @notice Sends dai and sets amount of zoo to claim after claim date.
	/// @notice Requires to be in whitelist.
	/// @param amount - amount of dai spent.
	function whitelistedBuy(uint256 amount) external
	{
		require(block.timestamp > idoStart, "IDO don't started yet");           // Requires to be date of IDO start.
		require(amountAllowed[msg.sender] >= amount, "amount exceeds limit");   // Requires allowed amount left to spent.
		require(block.timestamp <= whitelistPhase, "Phase 1 has ended");        // Requires date less than phase 1 end date.

		dai.transferFrom(msg.sender, address(this), amount);                    // Dai transfers from msg.sender to this contract.

		zooAllocated[msg.sender] += amount.mul(zooRate);                        // Records amount of zoo allocated to this person.
		zooAllocatedTotal += amount.mul(zooRate);                               // Records total amount of allocated zoo.

		amountAllowed[msg.sender] -= amount;                                    // Decreses amount of allowed dai to spend.

		emit daiInvested(amount);
	}

	/// @notice Function to buy rest of zoo for non whitelisted.
	/// @param amount - amount of DAI to spend.
	function notWhitelistedBuy(uint256 amount) external
	{
		require(block.timestamp > whitelistPhase, "Phase 1 still run");         // Requires date less than phase 1 end date.
		require(block.timestamp < idoEnd, "IDO finished");                      // Requires date less than IDO end date.
		require(unallocatedZoo() >= amount.mul(zooRate), "Not enough zoo");     // Requires to be enough unallocated zoo.
		require(amount <= saleLimit, "reached sale limit");                     // Requires amount to spend less than limit.
		require(partTaken[msg.sender] == false, "only one attempt per address");// There are only one attempt.

		dai.transferFrom(msg.sender, address(this), amount);                    // Dai transfers from msg.sender to this contract.

		partTaken[msg.sender] = true;                                           // Records that this address already take his part in IDO.
		zooAllocated[msg.sender] += amount.mul(zooRate);                        // Records amount of zoo allocated to this person.
		zooAllocatedTotal += amount.mul(zooRate);                               // Records total amount of allocated zoo.

		emit daiInvested(amount);
	}

	/// @notice Function to see amount of not allocated zoo tokens.
	/// @return availableZoo - amount of zoo available to buy.
	function unallocatedZoo() public view returns(uint256 availableZoo)
	{
		availableZoo = zoo.balanceOf(address(this)).sub(zooAllocatedTotal);
	}

	/// @notice Function to claim zoo.
	/// @notice sents all the zoo tokens bought to caller address.
	function claimZoo() external
	{
		require(zooAllocated[msg.sender] > 0, "no zoo allocated");              // Requires amount of dai spent more than zero.
		require(block.timestamp > claimDate, "Not the claim date yet");         // Requires date for claim.

		uint256 zooAmount = zooAllocated[msg.sender];                           // Amount of zoo to claim.

		zooAllocated[msg.sender] = 0;                                           // Sets amount of dai spent back to zero.

		zoo.transfer(msg.sender, zooAmount);                                    // Transfers zoo.

		emit zooClaimed(zooAmount);
	}

	/// @notice Function to claim dai and unsold zoo from IDO to team.
	function teamClaim() external 
	{
		require(block.timestamp > idoEnd, "IDO still run");                     // Requires to be end of IDO.

		uint256 daiAmount = dai.balanceOf(address(this));                       // Sets dai amount for all tokens invested.
		uint256 zooAmount = unallocatedZoo();                                   // Sets zoo amount for all unallocated zoo tokens.

		dai.transfer(team, daiAmount);                                          // Sends all the dai to team address.
		zoo.transfer(team, zooAmount);                                          // Sends all the zoo left to team address.

		emit teamClaimed(daiAmount, zooAmount);
	}
}
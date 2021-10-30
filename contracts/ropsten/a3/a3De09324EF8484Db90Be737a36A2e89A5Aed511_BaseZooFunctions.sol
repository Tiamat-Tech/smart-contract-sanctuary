pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

import "./interfaces/IZooFunctions.sol";
import "./NftBattleArena.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Contract BaseZooFunctions.
/// @notice Contracts for base implementation of some ZooDao functions.
contract BaseZooFunctions is IZooFunctions, Ownable
{
	using SafeMath for uint256;

	NftBattleArena public nftbattlearena;

	constructor () {}

	/// @notice Function for setting address of NftbattleArena contract.
	/// @param nftBattleArena - address of nftBattleArena contract.
	function init(address nftBattleArena) external onlyOwner {

		nftbattlearena = NftBattleArena(nftBattleArena);

		renounceOwnership();
	}

	/// @notice Function for choosing winner in battle.
	/// @param votesForA - amount of votes for 1st candidate.
	/// @param votesForB - amount of votes for 2nd candidate.
	/// @param random - generated random number.
	/// @return bool - returns true if 1st candidate wins.
	function decideWins(uint votesForA, uint votesForB, uint random) override external pure returns (bool)
	{
		uint mod = random % (votesForA + votesForB);
		return mod < votesForA;
	}

	/// @notice Function for generating random number.
	/// @param seed - multiplier for random number.
	/// @return random - generated random number.
	function getRandomNumber(uint256 seed) override external view returns (uint random) {

		random = uint(keccak256(abi.encodePacked(uint(blockhash(block.number - 1)) + seed))); // Get random number.
	}

	/// @notice Function for calculating voting with Dai in vote battles.
	/// @param amount - amount of dai used for vote.
	/// @return votes - final amount of votes after calculating.
	function computeVotesByDai(uint amount) override external view returns (uint votes)
	{
		if (block.timestamp < nftbattlearena.epochStartDate().add(nftbattlearena.firstStageDuration().add(4 minutes)))//2 days))) todo: change time
		{
			votes = amount.mul(13).div(10);                                          // 1.3 multiplier for votes.
		}
		else if (block.timestamp < nftbattlearena.epochStartDate().add(nftbattlearena.firstStageDuration().add(3 minutes)))//5 days)))
		{
			votes = amount;                                                          // 1.0 multiplier for votes.
		}
		else
		{
			votes = amount.mul(7).div(10);                                           // 0.7 multiplier for votes.
		}
	}

	/// @notice Function for calculating voting with Zoo in vote battles.
	/// @param amount - amount of Zoo used for vote.
	/// @return votes - final amount of votes after calculating.
	function computeVotesByZoo(uint amount) override external view returns (uint votes)
	{
		if (block.timestamp < nftbattlearena.epochStartDate().add(nftbattlearena.firstStageDuration().add(nftbattlearena.secondStageDuration().add(4 minutes))))//2 days))))
		{
			votes = amount.mul(13).div(10);                                         // 1.3 multiplier for votes.
		}
		else if (block.timestamp < nftbattlearena.epochStartDate().add(nftbattlearena.firstStageDuration().add(nftbattlearena.secondStageDuration().add(3 minutes))))//4 days))))
		{
			votes = amount;                                                         // 1.0 multiplier for votes.
		}
		else
		{
			votes = amount.mul(7).div(10);                                          // 0.7 multiplier for votes.
		}
	}
}
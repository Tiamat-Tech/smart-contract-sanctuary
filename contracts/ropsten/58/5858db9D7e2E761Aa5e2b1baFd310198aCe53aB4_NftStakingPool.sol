pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

import "./YieldFarm.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title NftStaking pool contract.
/// @notice Contract for staking nft-tokens.
contract NftStakingPool {

	YieldFarm public yieldFarm;

	mapping (address => mapping (uint256 => address)) public tokenStakedBy;

	/// @notice Event records info about staked nft in this pool.
	/// @param staker - address of nft staker.
	/// @param token - address of nft contract.
	/// @param id - id of staked nft.
	event StakedNft(address indexed staker, address indexed token, uint256 indexed id);

	/// @notice Event records info about withdrawed nft from this pool.
	/// @param staker - address of nft staker.
	/// @param token - address of nft contract.
	/// @param id - id of staked nft.
	event WithdrawedNft(address indexed staker, address indexed token, uint256 indexed id);

	/// @notice Contract constructor.
	constructor (address _yieldFarm)
	{
		yieldFarm = YieldFarm(_yieldFarm);
	}

	/// @notice Function for staking NFT in this pool.
	/// @param token - address of Nft token to stake
	/// @param id - id of nft token
	function stakeNft(address token, uint256 id) public
	{
		require(isParticipated(msg.sender) == true, "For yieldFarm stakers only!");   // Requires to take part in yield for staking.

		require(tokenStakedBy[token][id] == address(0), "this Id is already staked!");// Requires for token to be non-staked before.

		IERC721(token).transferFrom(msg.sender, address(this), id);                   // Sends NFT token to this contract.

		tokenStakedBy[token][id] = msg.sender;                                        // Sets the Id of token.

		emit StakedNft(msg.sender, token, id);                                        // Emits StakedNft event.
	}

	/// @notice Function for withdrawal Nft token back to owner.
	/// @param token - address of Nft token to unstake.
	/// @param id - id of nft token.
	function withdrawNft(address token, uint256 id) public
	{
		require(tokenStakedBy[token][id] == msg.sender, 
		"this Id is not staked, or you are not an owner!");         // Requires for token to be staked in this contract.

		IERC721(token).transferFrom(address(this), msg.sender, id); // Transfers token back to owner.

		tokenStakedBy[token][id] = address(0);                      // Changes the Id back to zero address.

		emit WithdrawedNft(msg.sender, token, id);                  // Emits WithdrawedNft event.
	}
	
	/// @notice Checks if user staked in yieldFarm.
	/// @param who - address staker.
	function isParticipated(address who) public view returns (bool result) {

		return yieldFarm.isParticipated(who) > 0;
	}
}
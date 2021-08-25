pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT
import "./YieldFarm.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title NftStaking pool contract.
/// @notice Contract for staking nft-tokens.
contract NftStakingPool is Ownable
{
	YieldFarm public yieldFarm;

	//uint256 public minDeposit;													// Minimum conditions for ability to stake.

	// mapping (address => bool) public nftContractIsAcceptableForStaking; 		// List of NFT available for staking.

	mapping (address => mapping (uint256 => address)) public tokenStakedBy;

	/// @notice Contract constructor.
	/// @param _yieldFarm - address of yieldFarm.
	constructor (address _yieldFarm) Ownable()
	{
		//minDeposit = _minDeposit; //uint256 _minDeposit,
		yieldFarm = YieldFarm(_yieldFarm);
	}

	// /// @notice Function for seting new NFT contract available for stacking.
	// /// @param token - address of contract Nft.
	// function allowNewContractForStaking(address token) onlyOwner external
	// {
	// 	nftContractIsAcceptableForStaking[token] = true;
	// }

	/// @notice Function for staking NFT in this pool.
	/// @param token - address of Nft token to stake
	/// @param id - id of nft token
	function stakeNft(address token, uint256 id) public
	{
		//require(nftContractIsAcceptableForStaking[token], "this contract is not allowed!"); //Requires for token contract to be allowed.
		require(tokenStakedBy[token][id] == address(0), "already staked!");// Requires for token to be non-staked before.

		IERC721(token).transferFrom(msg.sender, address(this), id);	// Sends NFT token to this contract.

		tokenStakedBy[token][id] = msg.sender;						// Sets the Id of token.
	}

	/// @notice Function for withdrawal Nft token back to owner.
	/// @param token - address of Nft token to unstake.
	/// @param id - id of nft token.
	function withdrawNft(address token, uint256 id) public
	{
		require(tokenStakedBy[token][id] == msg.sender);			// Requires for token to be staked in this contract.

		//IERC721(token).transfer(msg.sender, id);
		IERC721(token).transferFrom(address(this), msg.sender, id);	// Transfers token back to owner.

		tokenStakedBy[token][id] = address(0);						// Changes the Id back to zero address.
	}
	
	// /// @notice Function to check proper conditions for taking part in NftStakingPool.
	// /// @param who - address of staker.
	// function hasMinDeposit(address who) public view returns (bool)
	// {
	// 	//yieldFarm.stakers[who].deposit >= minDeposit;
	// 	//yieldFarm.stakers(who).deposit >= minDeposit;
	// 	(uint256 deposit,) = yieldFarm.stakers(who);				// Checks that staker took part in yieldFarm.
	// 	return deposit >= minDeposit;								// for needed amount.
	// }
}
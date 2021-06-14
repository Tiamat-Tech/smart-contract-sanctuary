pragma solidity ^0.7.0;
pragma abicoder v2;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title YieldFarm contract.
/// @notice Staking pool for uniswapV3 LP tokens for Zoo-Eth and distributing rewards logic.
contract YieldFarm is Ownable
{
	/// @notice Struct used for record claiming balance in staking pool.
	struct BalanceRecord
	{
		uint256 deposit;								// Amount of liquidity provided by staker.
		uint256 startEpoch;								// Number of epoch user started to stake.
	}

	/// @notice This struct stores amount of reward and LP tokens.
	struct Epoch
	{
		uint256 reward;									// Amount of reward in this epoch.
		uint256 lpTokensInEpoch;						// Amount of LP tokens in this epoch.
	}

	/// @notice Event records info about deposited LP tokens.
	/// @param staker - Address of staker.
	/// @param tokenId - Id of LP token.
	/// @param value - Liquidity of staked nft position.
	/// @param epoch - Epoch in which started to stake.
	event Deposited(address indexed staker, uint256 indexed tokenId, uint256 value, uint256 indexed epoch);

	/// @notice Event records info about withdrawal of LP tokens.
	/// @param staker - address of staker.
	/// @param tokenId - Id of LP token.
	/// @param value - Liquidity of staked nft position.
	/// @param epoch - Epoch in which token was withdrawed.
	event Withdrawal(address indexed staker, uint256 indexed tokenId, uint256 value, uint256 indexed epoch);

	/// @notice Event records info about amount of claimed reward.
	/// @param staker - address of staker.
	/// @param value - amount of reward claimed.
	/// @param epoch - epoch in which reward was claimed.
	event Claimed(address indexed staker, uint256 value, uint256 indexed epoch);

	/// @notice Wraps Uniswap V3 positions in the ERC721 non-fungible token interface.
	INonfungiblePositionManager public nonFungiblePositionManager;
	IERC20 public token;								// Token used for rewards payments.
	IERC20 public token0;								// Quote of uniswap trade pair.
	IERC20 public token1;								// Back quote of uniswap trade pair.
	uint256 public currentEpoch;							// Number of current epoch.
	mapping (uint256 => Epoch) public epochs;				// Epochs list.
	mapping (address => BalanceRecord) public stakers;	// List of stakers.
	mapping (uint256 => address) public investedBy;		// list of adresses of stakers.
	uint256 public claimedTotal;							// Amount of reward claimed.
	uint256 public pastEpochRewardSum;						// Sum of rewards from previous epochs.
	uint256 public lastUpdateDate;							// Date of last reward from epoch.
	mapping (uint256 => uint256) public shares;				// Amount of liquidity which had token with this Id while entering pool.

	/// @notice Contract constructor.
	constructor (address _nonFungiblePositionManager) Ownable()
	{
		nonFungiblePositionManager = INonfungiblePositionManager(_nonFungiblePositionManager);
	}

	/// @notice This function initializate token addresses and is used only once.
	/// @param _token - Token used for rewards payments.
	/// @param _token0 - Quote of uniswap trade pair.
	/// @param _token1 - Back quote of uniswap trade pair.
	function init(address _token, address _token0, address _token1) onlyOwner() external
	{
		token = IERC20(_token);
		token0 = IERC20(_token0);
		token1 = IERC20(_token1);

		transferOwnership(address(0));
	}

	/// @notice This function recalculates rewards.
	function updateInfo() external
	{
		require(block.timestamp > lastUpdateDate + 7 days);			// Require for date to be 7 days after last function call

		uint256 total = claimedTotal + token.balanceOf(address(this));	// Total amount of reward.
		uint256 rewardFromLastEpoch = total - pastEpochRewardSum;		// Calculate amount of reward from last epoch.
		epochs[currentEpoch + 1].reward = rewardFromLastEpoch;		// Sets reward for next epoch.
		epochs[currentEpoch + 1].lpTokensInEpoch += epochs[currentEpoch].lpTokensInEpoch; // Sets number of stakers in epoch.
		currentEpoch++;												// Increses number of current epoch.
		lastUpdateDate = block.timestamp;							// Sets the date of last info update.
	}
	
	/*
	/// @notice This function deposits new LP token to reward pool.
	/// @param who - address of staker.
	/// @param id - id of token.
	function _deposit(address who, uint id) internal
	{
		(,, address _token0, address _token1,,,,,,,,) = nonFungiblePositionManager.positions(id);	 // Get params of LP token.
		require(address(token0) == _token0 && address(token1) == _token1, "Not allowed trade pair!");// Require for trade pair to be allowed.

		nonFungiblePositionManager.transferFrom(who, address(this), id);							 // Calls transferFrom function from staker, to this smart contract address and with Id of lp token.
		investedBy[id] = msg.sender;																 // Sets the token condition to "staked".
		claimFor(who);																				 // Calls claimFor function for staker.
		(,,,,,,,uint256 value,,,,) = nonFungiblePositionManager.positions(id);						 // Get value of liquidity in LP token with this Id.
		stakers[who].deposit += value;																 // Increase the deposited value of zoo tokens of staker.
		shares[id] = value;																			 // sets the share value of token with this Id.
		epochs[currentEpoch + 1].lpTokensInEpoch += value;											 // Increase the value of lp tokens in next epoch.

		emit Deposited(who, id, value, currentEpoch);												 // emits Deposited event
	}
	*/

	/// @notice This function deposits create LP token on uniswap and stake it in staking pool.
	/// @param params - Params of LP token.
	function deposit(INonfungiblePositionManager.MintParams calldata params) external
	{
		require(params.token0 == address(token0) && params.token1 == address(token1), "Wrong tradepair");	// Requires correct tradepair(Zoo-WEth).

		uint256 numberOfToken0 = params.amount0Desired;								// Sets number of Zoo deposited.
		uint256 numberOfToken1 = params.amount1Desired;								// Sets number of Weth deposited.

		token0.transferFrom(msg.sender, address(this), numberOfToken0);				// Transfers Zoo tokens to this contract.
		token1.transferFrom(msg.sender, address(this), numberOfToken1);				// Transfers Weth tokens to this contract.

		(uint256 id, uint256 liquidity, uint256 amount0, uint256 amount1) = nonFungiblePositionManager.mint(params); 	// Sets params of Lp token.

		token0.transfer(msg.sender, numberOfToken0 - amount0);						// Transfers Zoo tokens to uniswap.
		token1.transfer(msg.sender, numberOfToken1 - amount1);						// Transfers Weth tokens to uniswap.

		investedBy[id] = msg.sender;												// Sets id of owner.
		claimFor(msg.sender);														// Calls claimFor function for staker.

		stakers[msg.sender].deposit += amount0;										// Increases amount of tokens deposited by owner.
		shares[id] = amount0;														// Sets the share value of token with this Id.
		epochs[currentEpoch + 1].lpTokensInEpoch += amount0;						// Increases amount of Lp tokens in next epoch.

		emit Deposited(msg.sender, id, amount0, currentEpoch);						// Records info about deposit.
	}

	/// @notice Function for withdrawal lp token from pool.
	/// @param tokenId - Id of Lp token.
	function withdraw(uint256 tokenId) external
	{
		_withdraw(msg.sender, tokenId);									// Calls _withdraw function with address sender and Id of lp token.
	}

	/// @notice Internal function for withdrawal lp token from pool.
	/// @param who - address of staker.
	/// @param id - Id of Lp token.
	function _withdraw(address who, uint256 id) internal
	{
		require(investedBy[id] == who);									// Require the ownership of lp token.
		nonFungiblePositionManager.transferFrom(address(this), who, id);// Calls transferFrom function from this smart contract to owner of token with this Id.
		claimFor(who);													// Calls claimFor function for address receiver of reward.
		uint256 value = shares[id];										// Sets value proportional to share of token with this Id.
		stakers[who].deposit -= value;									// Decreases value of staker's deposit.
		epochs[currentEpoch].lpTokensInEpoch -= value;					// Decreases amount of tokens in current epoch.
		shares[id] = 0;													// Sets share value of this lp token to zero.
		investedBy[id] = address(0);									// Sets token condition to "unstaked".

		emit Withdrawal(who, id, value, currentEpoch);
	}

	/// @notice This function claims reward for staker.
	/// @param who - address recipient of reward.
	function claimFor(address who) public
	{
		uint256 claimValue = 0;													// Sets reward value of staker to zero by default.
		uint256 staked = stakers[who].deposit;										// Gets amount of tokens deposited by staker.
		
		for (uint256 i = stakers[who].startEpoch; i < currentEpoch; i++)			// Calculate number of epochs staker was participated.
		{
			claimValue += epochs[i].reward * staked / epochs[i].lpTokensInEpoch;// Calculates reward for staker.
		}

		stakers[who].startEpoch = currentEpoch;									// Resets number of epochs staker was participated.
		token.transfer(who, claimValue);										// Calls transfer function for recipient and value of reward.

		emit Claimed(who, claimValue, currentEpoch);							// Calls event that records amount of reward staker receive.
	}

	/// @notice This function collects fee from LP token.
	/// @param params - params for calling collect function.
	function collect(INonfungiblePositionManager.CollectParams memory params) external payable returns (uint256 amount0, uint256 amount1)
	{
		require(investedBy[params.tokenId] == msg.sender);						// Requires that this lp token with such params belong to sender.

		return nonFungiblePositionManager.collect(params);						// Calls collect function from lp token and returns result.
	}
}
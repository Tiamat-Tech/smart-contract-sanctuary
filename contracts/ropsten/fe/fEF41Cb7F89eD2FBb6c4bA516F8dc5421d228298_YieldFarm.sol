pragma solidity ^0.7.0;
pragma abicoder v2;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title YieldFarm contract.
/// @notice Contract for yield farming with staking uniswapV3 LP tokens with Zoo-Dai in,
/// @notice and epochs with rewards in Zoo tokens for staking.
contract YieldFarm is Ownable
{
	/// @notice Struct for recording deposits in staking pool.
	struct BalanceRecord
	{
		uint256 deposit;								// Amount of liquidity provided by staker.
		uint256 startEpoch;								// Number of epoch user started to stake.
	}

	/// @notice Struct for storing amount of reward and LP tokens in current epoch.
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

	/// @notice Event records date of last epoch reward.
	event UpdatedInfo(uint256 date);

	INonfungiblePositionManager public nonFungiblePositionManager;	// Wraps Uniswap V3 positions in the ERC721 non-fungible token interface.
	IERC20 public token;											// Token used for rewards payments.
	IERC20 public token0;											// Quote of uniswap trade pair.
	IERC20 public token1;											// Back quote of uniswap trade pair.
	uint256 public currentEpoch;									// Number of current epoch.
	mapping (uint256 => Epoch) public epochs;						// Epochs list.
	mapping (address => BalanceRecord) public stakers;				// List of stakers.
	mapping (uint256 => address) public investedBy;					// list of adresses of stakers.
	uint256 public claimedTotal;									// Amount of reward claimed.
	uint256 public pastEpochRewardSum;								// Sum of rewards from previous epochs.
	uint256 public lastUpdateDate;									// Date of last reward from epoch.
	mapping (uint256 => uint256) public shares;						// Amount of liquidity which had token with this Id while entering pool.

	/// @notice Contract constructor.
	constructor (address _nonFungiblePositionManager) Ownable()
	{
		nonFungiblePositionManager = INonfungiblePositionManager(_nonFungiblePositionManager);
	}

	/// @notice Function to initializate token addresses, used only once.
	/// @param _token - Token used for rewards payments.
	/// @param _token0 - Quote of uniswap trade pair.
	/// @param _token1 - Back quote of uniswap trade pair.
	function init(address _token, address _token0, address _token1) onlyOwner() external
	{
		token = IERC20(_token);
		token0 = IERC20(_token0);
		token1 = IERC20(_token1);

		renounceOwnership();
	}

	/// @notice Function for recalculating rewards.
	function updateInfo() external
	{
		require(block.timestamp > lastUpdateDate);// + 7 days, "seven days should be passed from last update!");	// Require for date to be 7 days after last function call.

		uint256 total = claimedTotal + token.balanceOf(address(this));						// Total amount of reward.
		uint256 rewardFromLastEpoch = total - pastEpochRewardSum;							// Calculate amount of reward from last epoch.
		epochs[currentEpoch + 1].reward = rewardFromLastEpoch;								// Sets reward for next epoch.
		epochs[currentEpoch + 1].lpTokensInEpoch += epochs[currentEpoch].lpTokensInEpoch; 	// Sets number of stakers in epoch.
		currentEpoch++;																		// Increses number of current epoch.
		lastUpdateDate = block.timestamp;													// Sets the date of last info update.

		emit UpdatedInfo(block.timestamp);													// Records date of calling updateInfo function.
	}

	/// @notice Function for depositing created LP token on uniswap and stake it in staking pool.
	/// @param params - mint params of LP token:
	/// @dev token0 - The address of the token0 for a specific pool.
	/// @dev token1 - The address of the token1 for a specific pool.
  	/// @dev fee - The fee associated with the pool.
  	/// @dev tickLower - The lower end of the tick range for the position.
  	/// @dev tickUpper - The higher end of the tick range for the position.
  	/// @dev amount0Desired - The desired amount of token0 to be spent.
  	/// @dev amount1Desired - The desired amount of token1 to be spent.
  	/// @dev amount0Min - The minimum amount of token0 to spend, which serves as a slippage check.
  	/// @dev amount1Min - The minimum amount of token1 to spend, which serves as a slippage check.
  	/// @dev recipient - The address recipient of lp token.
  	/// @dev deadline - The time by which the transaction must be included to effect the change.
	function deposit(INonfungiblePositionManager.MintParams calldata params) external
	{
		require(params.token0 == address(token0) && params.token1 == address(token1), "Wrong tradepair");// Requires correct tradepair(Zoo-DAI).

		uint256 numberOfToken0 = params.amount0Desired;										// Sets total number of Zoo for transaction.
		uint256 numberOfToken1 = params.amount1Desired;										// Sets total number of Dai for transaction.
		
		token0.transferFrom(msg.sender, address(this), numberOfToken0);						// Transfers Zoo tokens to this contract.
		token1.transferFrom(msg.sender, address(this), numberOfToken1);						// Transfers DAi tokens to this contract.

		token0.approve(0xC36442b4a4522E871399CD717aBDD847Ab11FE88, numberOfToken0);
		token1.approve(0xC36442b4a4522E871399CD717aBDD847Ab11FE88, numberOfToken1);

		(uint256 id, uint256 liquidity, uint256 amount0, uint256 amount1) = nonFungiblePositionManager.mint(params); // Mints Zoo-Dai Nft lp token.

		token0.transfer(msg.sender, numberOfToken0 - amount0);								// Transfers unused rest of Zoo back to owner.
		token1.transfer(msg.sender, numberOfToken1 - amount1);								// Transfers unused rest of DAI back to owner.

		investedBy[id] = msg.sender;														// Sets id of owner.
		claimFor(msg.sender);																// Calls claimFor function for staker.

		stakers[msg.sender].deposit += amount0;												// Increases amount of tokens deposited by owner.
		shares[id] = amount0;																// Sets the share value of token with this Id.
		epochs[currentEpoch + 1].lpTokensInEpoch += amount0;								// Increases amount of Lp tokens in next epoch.

		emit Deposited(msg.sender, id, amount0, currentEpoch);								// Records info about deposit.
	}

	/// @notice Function for withdrawal lp token from pool.
	/// @param tokenId - Id of Lp token.
	function withdraw(uint256 tokenId) external
	{
		_withdraw(msg.sender, tokenId);									// Calls _withdraw function with address sender and Id of lp token.
	}

	/// @param who - address of staker.
	/// @param id - Id of Lp token.
	function _withdraw(address who, uint256 id) internal
	{
		require(investedBy[id] == who, "Not the owner!");				// Require the ownership of lp token.
		nonFungiblePositionManager.transferFrom(address(this), who, id);// Calls transferFrom function from this smart contract to owner of token with this Id.
		claimFor(who);													// Calls claimFor function for address receiver of reward.
		uint256 value = shares[id];										// Sets value proportional to share of token with this Id.
		stakers[who].deposit -= value;									// Decreases value of staker's deposit.
		epochs[currentEpoch].lpTokensInEpoch -= value;					// Decreases amount of tokens in current epoch.
		shares[id] = 0;													// Sets share value of this lp token to zero.
		investedBy[id] = address(0);									// Sets token condition to "unstaked".

		emit Withdrawal(who, id, value, currentEpoch);
	}

	/// @notice Function for getting amount of rewards available for claiming.
	/// @param who - address of staker.
	function getPendingRewards(address who) external view returns (uint256 amount) {

		uint256 claimValue = 0;													// Sets reward value of staker to zero by default.
		uint256 staked = stakers[who].deposit;									// Gets amount of tokens deposited by staker.
		
		for (uint256 i = stakers[who].startEpoch; i < currentEpoch; i++)		// Calculate number of epochs staker was participated.
		{
			claimValue += epochs[i].reward * staked / epochs[i].lpTokensInEpoch;// Calculates reward for staker.
		}
		return claimValue;
	}

	/// @notice Function for claiming rewards for staker.
	/// @param who - address recipient of reward.
	function claimFor(address who) public
	{
		uint256 claimValue = 0;													// Sets reward value of staker to zero by default.
		uint256 staked = stakers[who].deposit;									// Gets amount of tokens deposited by staker.
		
		for (uint256 i = stakers[who].startEpoch; i < currentEpoch; i++)		// Calculate number of epochs staker was participated.
		{
			claimValue += epochs[i].reward * staked / epochs[i].lpTokensInEpoch;// Calculates reward for staker.
		}

		stakers[who].startEpoch = currentEpoch;									// Resets number of epochs staker was participated.
		token.transfer(who, claimValue);										// Calls transfer function for recipient and value of reward.

		emit Claimed(who, claimValue, currentEpoch);							// Calls event that records amount of reward staker receive.
	}

	/// @notice Function for collecting uniswap fee from LP token.
	/// @param params - collect params:
	/// @dev tokenId The ID of the NFT for which tokens are being collected,
    /// @dev recipient The account that should receive the tokens,
    /// @dev amount0Max The maximum amount of token0 to collect,
    /// @dev amount1Max The maximum amount of token1 to collect
	function collect(INonfungiblePositionManager.CollectParams memory params) external payable returns (uint256 amount0, uint256 amount1)
	{
		require(investedBy[params.tokenId] == msg.sender, "Should be called from token owner!");// Requires that this lp token with such params belong to sender.
		
		return nonFungiblePositionManager.collect(params);						// Calls uniswap collect function.

	}
}
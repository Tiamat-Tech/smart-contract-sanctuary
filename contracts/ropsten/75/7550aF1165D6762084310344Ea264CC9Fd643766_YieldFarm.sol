pragma solidity ^0.7.0;
pragma abicoder v2;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title YieldFarm contract.
/// @notice Contract for yield farming with staking uniswapV3 LP tokens with Zoo-Dai in,
/// @notice and epochs with rewards in Zoo tokens for staking.
contract YieldFarm is Ownable, ERC721
{
	using SafeMath for uint256;
	using SafeMath for int256;

	/// @notice Struct for recording deposits in staking pool.
	struct BalanceRecord
	{
		uint256 deposit;                              // Amount of liquidity provided by staker in token.
		uint256 startEpoch;                           // Number of epoch user started to stake.
		uint256 endEpoch;
	}

	/// @notice Struct for storing amount of reward and LP tokens in current epoch.
	struct Epoch
	{
		uint256 reward;                               // Amount of reward in this epoch.
		int256 zooTokensInEpoch;                      // Amount of LP tokens in this epoch.
	}

	/// @notice Event records info about deposited LP tokens.
	/// @param staker - Address of staker.
	/// @param tokenId - Id of LP token.
	/// @param value - Liquidity of staked nft position.
	/// @param startEpoch - Epoch in which started to stake.
	event Deposited(address indexed staker, uint256 indexed tokenId, uint256 value, uint256 indexed startEpoch);

	/// @notice Event records info about withdrawal of LP tokens.
	/// @param staker - address of staker.
	/// @param tokenId - Id of LP token.
	/// @param value - Liquidity of staked nft position.
	/// @param endEpoch - Epoch in which token was withdrawed.
	event Withdrawal(address indexed staker, uint256 indexed tokenId, uint256 value, uint256 indexed endEpoch);

	/// @notice Event records info about amount of claimed reward.
	/// @param staker - address of staker.
	/// @param id - id of LP token in yieldFarm.
	/// @param value - amount of reward claimed.
	/// @param epoch - epoch in which reward was claimed.
	event Claimed(address indexed staker, uint256 id, uint256 value, uint256 indexed epoch);

	/// @notice Event records date of last epoch reward.
	event UpdatedInfo(uint256 indexed date, uint256 indexed epochStarted, uint256 indexed rewardFromLastEpoch);

	INonfungiblePositionManager public nonFungiblePositionManager; // Wraps Uniswap V3 positions in the ERC721 non-fungible token interface.
	address uniPosManager;                                         // Address of uniswap position manager.
	IERC20 public token;                                           // Token used for rewards payments.
	IERC20 public token0;                                          // Quote of uniswap trade pair.
	IERC20 public token1;                                          // Back quote of uniswap trade pair.
	uint256 public currentEpoch;                                   // Number of current epoch.
	mapping (uint256 => Epoch) public epochs;                      // Mapping for epoch info.
	mapping (uint256 => address) public investedBy;                // list of adresses of stakers.
	uint256 public claimedTotal;                                   // Amount of reward claimed.
	uint256 public pastEpochRewardSum;                             // Sum of rewards from previous epochs.
	uint256 public lastUpdateDate;                                 // Date of last reward from epoch.
	mapping (uint => BalanceRecord) public positions;              // Parameters of stakers deposit in yield.
	mapping (address => uint256) public isParticipated;            // Records that user staked in yield.

	/// @notice Contract constructor.
	constructor (address _nonFungiblePositionManager) Ownable() ERC721("YieldFarm NFT", "YFNFT")
	{
		nonFungiblePositionManager = INonfungiblePositionManager(_nonFungiblePositionManager);
		uniPosManager = _nonFungiblePositionManager;
	}

	/// @notice Function to initializate token addresses, used only once.
	/// @param _token - Token used for rewards payments.
	/// @param _token0 - Quote of uniswap trade pair.
	/// @param _token1 - Back quote of uniswap trade pair.
	function init(address _token, address _token0, address _token1) onlyOwner() external
	{
		token = IERC20(_token);         // Sets token for rewards in epochs.
		token0 = IERC20(_token0);       // Sets 1st token for trade pair.
		token1 = IERC20(_token1);       // Sets 2nd token for trade pair.

		renounceOwnership();            // Sets owner to zero address.
	}

	/// @notice Function for recalculating rewards.
	function updateInfo() external
	{
		require(block.timestamp > lastUpdateDate);//todo: add time: + 7 days, "seven days should be passed from last update!"); // Require for date to be 7 days after last function call.

		uint256 total = claimedTotal.add(token.balanceOf(address(this)));         // Total amount of reward.
		uint256 rewardFromLastEpoch = total.sub(pastEpochRewardSum);              // Calculate amount of reward from last epoch.
		epochs[currentEpoch + 1].reward = rewardFromLastEpoch;                    // Sets reward for next epoch.
		epochs[currentEpoch + 1].zooTokensInEpoch += epochs[currentEpoch].zooTokensInEpoch;// Sets amount of Zoo tokens in epoch.
		currentEpoch++;                                                           // Increses number of current epoch.
		lastUpdateDate = block.timestamp;                                         // Sets the date of last info update.
		pastEpochRewardSum = total;

		emit UpdatedInfo(block.timestamp, currentEpoch, rewardFromLastEpoch);     // Records date of calling updateInfo function.
	}

	/// @notice Function for minting LP token on uniswap and stake it in staking pool.
	/// @param params - mint params of LP token:
	/// @dev token0 - should be Zoo.
	/// @dev token1 - should be Dai.
  	/// @dev fee - uniswap pool fee, should be "500", "3000", or "10000".
  	/// @dev tickLower - The lower end of the tick range for the position from actual price as a zero point.
  	/// @dev tickUpper - The higher end of the tick range for the position, should be set in accordance of actual price.
  	/// @dev amount0Desired - The desired amount of Zoo to be spent.
  	/// @dev amount1Desired - The desired amount of Dai to be spent.
  	/// @dev amount0Min - The minimum amount of Zoo to spend, which serves as a slippage check.
  	/// @dev amount1Min - The minimum amount of Dai to spend, which serves as a slippage check.
  	/// @dev recipient - The address recipient of LP token, should be owner, not yield address.
  	/// @dev deadline - The time by which the transaction must be included to effect the change, counts in seconds, should be big enought.
	function mint(INonfungiblePositionManager.MintParams calldata params) external
	{
		require(params.token0 == address(token0) && params.token1 == address(token1), "Wrong tradepair");// Requires correct tradepair(Zoo-DAI).

		uint256 numberOfToken0 = params.amount0Desired;                         // Sets total number of Zoo for transaction.
		uint256 numberOfToken1 = params.amount1Desired;                         // Sets total number of Dai for transaction.
		
		token0.transferFrom(msg.sender, address(this), numberOfToken0);         // Transfers Zoo tokens to this contract.
		token1.transferFrom(msg.sender, address(this), numberOfToken1);         // Transfers DAi tokens to this contract.

		token0.approve(uniPosManager, numberOfToken0);                          // Approving
		token1.approve(uniPosManager, numberOfToken1);                          // Approving

		(uint256 id, uint256 liquidity, uint256 amount0, uint256 amount1) = nonFungiblePositionManager.mint(params);// Mints Zoo-Dai Nft lp token.
	
		token0.transfer(msg.sender, numberOfToken0.sub(amount0));               // Transfers unused rest of Zoo back to owner.
		token1.transfer(msg.sender, numberOfToken1.sub(amount1));               // Transfers unused rest of DAI back to owner.

		_mint(msg.sender, id);                                                  // Mints yield token with same id from uniswap.
		investedBy[id] = msg.sender;                                            // Sets ownership of minted token with this Id.
		positions[id].deposit = amount0;                                        // Sets deposit amount for this id.
		positions[id].startEpoch = currentEpoch + 1;                            // Sets start epoch for this id.

		epochs[currentEpoch + 1].zooTokensInEpoch += int256(amount0);           // Increases amount of Lp tokens in next epoch.

		isParticipated[msg.sender]++;                                           // Increases amount in mapping for taking part in yield.

		emit Deposited(msg.sender, id, amount0, currentEpoch);                  // Records info about deposit.
	}

	/// @notice Function for withdrawal lp token from pool.
	/// @param tokenId - Id of Lp token.
	function withdraw(uint256 tokenId) external
	{
		_withdraw(msg.sender, tokenId);                                 // Calls _withdraw function with address sender and Id of lp token.
	}

	/// @param who - address of staker.
	/// @param id - Id of Lp token.
	function _withdraw(address who, uint256 id) internal
	{
		require(investedBy[id] == who, "Not the owner!");               // Require the ownership of lp token.
		nonFungiblePositionManager.transferFrom(address(this), who, id);// Calls transferFrom function from this smart contract to owner of token with this Id.
		positions[id].endEpoch = currentEpoch;

		uint256 value = positions[id].deposit;                          // Sets value proportional to share of token with this Id.
		
		if (positions[id].endEpoch <= positions[id].startEpoch) {
			epochs[currentEpoch + 1].zooTokensInEpoch -= int256(value); // Decreases amount of tokens in current epoch.
		}
		else {
			epochs[currentEpoch].zooTokensInEpoch -= int256(value);     // Decreases amount of tokens in current epoch.
		}

		claimFor(who, id);                                              // Calls claimFor function for address receiver of reward.

		investedBy[id] = address(0);                                    // Sets token condition to "unstaked".

		isParticipated[who]--;                                          // Reduces amount in mapping for taking part in yield.

		emit Withdrawal(who, id, value, currentEpoch);
	}

	/// @notice Function for getting amount of rewards available for claiming.
	/// @param id - address of staker.
	function getPendingRewards(uint id) external view returns (uint256 amount) {

		uint256 claimValue = 0;                                                  // Sets reward value of staker to zero by default.
		uint256 staked = positions[id].deposit;                                  // Gets amount of tokens deposited by staker.

		if (positions[id].endEpoch != 0) return 0;                               // Returns zero if token unstaked or already claimed
		
		for (uint256 i = positions[id].startEpoch; i < currentEpoch; i++)        // Calculate number of epochs staker was participated.
		{
			if (epochs[i].zooTokensInEpoch != 0) {
				claimValue = claimValue.add(((epochs[i].reward).mul(staked)).div(uint256(epochs[i].zooTokensInEpoch)));// Calculates reward for staker.
			}
		}
		return claimValue;
	}

	/// @notice Function for claiming rewards for staker.
	/// @param who - address recipient of reward.
	/// @param id - id of yieldfarm nf token.
	function claimFor(address who, uint id) public
	{	
		require(ownerOf(id) == who);                                     // Requires for recipient to be an owner of token.

		uint256 claimValue = 0;                                          // Sets reward value of staker to zero by default.
		uint256 staked = positions[id].deposit;                          // Gets amount of tokens deposited by staker.
		
		if (positions[id].endEpoch != 0) return;                         // Reverts if token unstaked or already claimed

		for (uint256 i = positions[id].startEpoch; i < currentEpoch; i++)// Calculate number of epochs staker was participated.
		{
			if (epochs[i].zooTokensInEpoch != 0) {
				claimValue = claimValue.add(((epochs[i].reward).mul(staked)).div(uint256(epochs[i].zooTokensInEpoch)));// Calculates reward for staker.
			}
		}
		
		claimedTotal = claimedTotal.add(claimValue);                     // Increases claimedTotal amount.
		positions[id].startEpoch = currentEpoch;                         // Resets number of epoch staker started from.
		token.transfer(who, claimValue);                                 // Calls transfer function for recipient and value of reward.
		
		emit Claimed(who, id, claimValue, currentEpoch);                 // Calls event that records amount of reward staker receive.
	}

	/// @notice Function for collecting uniswap fee from LP token.
	/// @param params - collect params:
	/// @dev tokenId The ID of the NFT for which tokens are being collected,
    /// @dev recipient The account that should receive the tokens,
    /// @dev amount0Max The maximum amount of token0 to collect,
    /// @dev amount1Max The maximum amount of token1 to collect
	function collect(INonfungiblePositionManager.CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1)
	{
		require(investedBy[params.tokenId] == msg.sender, 
		"Should be called from token owner!");                           // Requires that this lp token with such params belong to sender.
		
		return nonFungiblePositionManager.collect(params);               // Calls uniswap collect function.
	}
}
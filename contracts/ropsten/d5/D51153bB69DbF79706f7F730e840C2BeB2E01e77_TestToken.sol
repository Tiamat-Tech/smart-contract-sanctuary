// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@pancakeswap-libs/pancake-swap-core/contracts/interfaces/IPancakePair.sol";
import "@pancakeswap-libs/pancake-swap-core/contracts/interfaces/IPancakeFactory.sol";
import "pancakeswap-peripheral/contracts/interfaces/IPancakeRouter02.sol";

/// @title TestToken
/// @notice TestToken Contract implementing ERC20 standard
/// @dev To be deployed as TestToken token for use in Test games.
///		PancakeRouter should be defined post creation.
///		PancakePair should be defined post launch.
contract TestToken is ERC20PresetFixedSupply, AccessControl, Ownable {

	/// Fee for liquidity, marketing, development, etc.
	/// Create with 99% tax to combat bots, adjust later with max limited fee amount
	uint16 public operationsFee = 990;
	/// Percentage of operations fee to add to liquidity
	uint256 public feeLiquidityPercentage = 400;
	/// Fee for staking pools, etc.
	uint8 public rewardsFee = 0;

	/// Addresses to receive taxes
	address private _operationsWallet;
	address private _rewardsVault;
	address private _liquidityRecipient;

	mapping(address => bool) _isExcludedFromFee;
	mapping(address => bool) _isExcludedFromMaxTx;

	IPancakeRouter02 public PancakeRouter;
	IPancakePair public PancakePair;
	
	bool public feesEnabled = true;
	bool public swapEnabled = true;

	uint256 public maxTxAmount = 1000000000e18;
	uint256 public swapThreshold = 100000e18;
	bool private _swapActive = false;

	modifier swapSemaphore() {
		_swapActive = true;
		_;
		_swapActive = false;
	}

	/// Events on variable changes
	event PancakePairUpdated(address pair);
	event PancakeRouterUpdated(address router);
	event OperationsFeeUpdated(uint8 fee);
	event RewardsFeeUpdated(uint8 fee);
	event OperationsWalletUpdated(address wallet);
	event RewardsVaultUpdated(address vault);
	event FeeLiquidityPercentageUpdated(uint256 percentage);
	event IncludedInFees(address account);
	event ExcludedFromFees(address account);
	event IncludedInMaxTransaction(address account);
	event ExcludedFromMaxTransaction(address account);
	event MaxTransactionUpdated(uint256 maxTxAmount);
	event FeesEnabledUpdated(bool enabled);
	event SwapEnabledUpdated(bool enabled);
	event SwapThresholdUpdated(uint256 threshold);
	event LiquidityRecipientUpdated(address recipient);
	event SwapTokensForNative(uint256 amount);
	event AddLiquidity(uint256 tokenAmount, uint256 nativeAmount);
	

	/// TestToken constructor
	/// @param name The token name
	/// @param symbol The token symbol
	/// @param initialSupply The token final initialSupply to mint
	/// @param owner The address to send minted supply to
	constructor(string memory name, string memory symbol, uint256 initialSupply, address owner) ERC20PresetFixedSupply(name, symbol, initialSupply, owner) {
		_isExcludedFromFee[address(this)] = true;
		_isExcludedFromFee[owner] = true;

		// Define administrator roles that can add/remove from given roles
		_setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);

		// Add deployer to admin roles
		_setupRole(DEFAULT_ADMIN_ROLE, owner);
	}


	/// CONTRACT FUNDS ///

	/// Receive native funds on contract (for swap or any accidental sends)
	receive() external payable {}

	/// Withdraw any native funds to sender address
	function withdrawNative() external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(_withdrawNative(_msgSender(), address(this).balance), "TestToken: Withdraw failed");
	}

	/// Withdraw any ERC20 tokens to sender address
	/// @param _token The address of ERC20 token to withdraw
	/// @param amount The amount of the token to withdraw
	function withdrawToken(address _token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
		IERC20(_token).transfer(_msgSender(), amount);
	}


	/// PUBLIC VIEWS ///

	/// Check if address is excluded from fees
	function isExcludedFromFee(address account) external view returns(bool) {
		return _isExcludedFromFee[account];
	}

	/// Check if address is excluded from max transaction
	function isExcludedFromMaxTx(address account) external view returns(bool) {
		return _isExcludedFromMaxTx[account];
	}

	/// Get total fees (divide by 10 for percentage value)
	function totalFees() external view returns(uint256) {
		if (feesEnabled) {
			return operationsFee + rewardsFee;
		} 
		return 0;
	}


	/// ADMINISTRATION ///

	/// Quick function to create pair for Retromoon and WBNB
	function createNativePair() external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(address(PancakeRouter) != address(0), "TestToken: Cannot create Pair before Router is set");
		IPancakeFactory factory = IPancakeFactory(PancakeRouter.factory());
		address pair = factory.createPair(address(this), PancakeRouter.WETH());
		PancakePair = IPancakePair(pair);
		emit PancakePairUpdated(pair);
	}

	/// Set pancake/token pair address
	function setPrimaryPairAddress(address pair) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(pair != address(0), "TestToken: Cannot set Pair to zero address");
		PancakePair = IPancakePair(pair);
		emit PancakePairUpdated(pair);
	}

	/// Set pancake router address
	function setRouterAddress(address router) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(router != address(0), "TestToken: Cannot set Router to zero address");
		PancakeRouter = IPancakeRouter02(router);
		_approve(address(this), address(PancakeRouter), ~uint256(0));
		emit PancakeRouterUpdated(router);
	}

	/// Set address to receive operations funds
	function setOperationsWallet(address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(wallet != address(0), "TestToken: Cannot set Wallet to zero address");
		_operationsWallet = wallet;
		emit OperationsWalletUpdated(wallet);
	}

	/// Set address to receive rewards tokens
	function setRewardsVault(address vault) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(vault != address(0), "TestToken: Cannot set Vault to zero address");
		_rewardsVault = vault;
		emit RewardsVaultUpdated(vault);
	}

	/// Set liquidity recipient
	function setLiquidityRecipient(address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_liquidityRecipient = recipient;
		emit LiquidityRecipientUpdated(recipient);
	}

	/// Set feesEnabled flag
	function setFeesEnabled(bool _enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
		feesEnabled = _enabled;
		emit FeesEnabledUpdated(_enabled);
	}

	/// Include address in fees
	function includeInFee(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_isExcludedFromFee[account] = false;
		emit IncludedInFees(account);
	}

	/// Exclude address from fees
	function excludeFromFee(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_isExcludedFromFee[account] = true;
		emit ExcludedFromFees(account);
	}

	/// Include address in max tx
	function includeInMaxTx(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_isExcludedFromMaxTx[account] = false;
		emit IncludedInMaxTransaction(account);
	}

	/// Exclude address from max tx
	function excludeFromMaxTx(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_isExcludedFromMaxTx[account] = true;
		emit ExcludedFromMaxTransaction(account);
	}

	/// Set max transaction amount
	function setMaxTxAmount(uint256 maxTx) external onlyRole(DEFAULT_ADMIN_ROLE) {
		uint256 percentage = maxTx * 10e2 / totalSupply();
		require(percentage >= 1, "TestToken: Cannot set max transaction less than 0.1%");
		maxTxAmount = maxTx;
		emit MaxTransactionUpdated(maxTx);
	}

	/// Set max transaction percentage
	/// @param maxTxPercentage Max transaction percentage where 10 = 1%
	function setMaxTxPercentage(uint256 maxTxPercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(maxTxPercentage >= 1, "TestToken: Cannot set max transaction less than 0.1%");
		uint256 maxTx = totalSupply() * maxTxPercentage / 10e2;
		maxTxAmount = maxTx;
		emit MaxTransactionUpdated(maxTx);
	}

	/// Set swap threshold of tokens to swap to native
	function setSwapThreshold(uint256 threshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(threshold > 0, "TestToken: Cannot set threshold to zero");
		swapThreshold = threshold;
		emit SwapThresholdUpdated(threshold);
	}
	
	/// Set swapEnabled flag
	function setSwapEnabled(bool _enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
		swapEnabled = _enabled;
		emit SwapEnabledUpdated(_enabled);
	}

	/// Set operations fee to take on buys/sells
	function setOperationsFee(uint8 fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(fee <= 200, "TestToken: max operations fee is 20%");
		operationsFee = fee;
		emit OperationsFeeUpdated(fee);
	}

	/// Set rewards (e.g. staking pool) fees to take on buys/sells
	function setRewardsFee(uint8 fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(fee <= 100, "TestToken: max rewards fee is 10%");
		rewardsFee = fee;
		emit RewardsFeeUpdated(fee);
	}

	/// Set percentage of operations fee to add to liquidity
	function setFeeLiquidityPercentage(uint16 percentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(percentage <= 1000, "TestToken: max fee liquidity percentage is 100%");
		feeLiquidityPercentage = percentage;
		emit FeeLiquidityPercentageUpdated(percentage);
	}


	/// TRANSFER AND SWAP ///

	/// @dev Check if transfer should take fee, only take fee on buys/sells
	function _shouldTakeFee(address sender, address receiver) internal virtual view returns (bool) {
		return (sender == address(PancakePair) || receiver == address(PancakePair)) && 
				!(_isExcludedFromFee[sender] || _isExcludedFromFee[receiver]);
	}

	/// @dev Check if transfer should limit transaction amount
	function _shouldLimitTx(address sender, address receiver) internal virtual view returns (bool) {
		return (sender == address(PancakePair) || receiver == address(PancakePair)) &&
				!(_isExcludedFromMaxTx[sender] || _isExcludedFromMaxTx[receiver]);
	}
	
	/// @dev Calculate individual and total fee amounts for a given transfer amount
	/// @param amount The transfer amount
	/// @return totalFeeAmount The total fee value to take from transfer amount
	/// @return operationsFeeAmount The operations fee value to take from transfer amount
	/// @return rewardFeeAmount The rewards fee value to take from transfer amount
	function _calculateFees(uint256 amount)
		internal
		view
		returns (
			uint256 totalFeeAmount,
			uint256 operationsFeeAmount,
			uint256 rewardFeeAmount
		)
	{
		operationsFeeAmount = amount * operationsFee / 10e2;
		rewardFeeAmount = amount * rewardsFee / 10e2;
		totalFeeAmount = rewardFeeAmount + operationsFeeAmount;
	}

	/// @notice Transfer amount, taking taxes (if enabled) for operations and reward pool.
	///			If enabled and threshold is reached, also swap taxes to native currency and add to liquidity.
	/// @inheritdoc	ERC20
	function _transfer(
		address from,
		address to,
		uint256 amount
	) internal virtual override {
		if (_shouldLimitTx(from, to)) {
			require(amount <= maxTxAmount, "TestToken: Transfer amount over maxTxAmount");
		}

		(uint256 totalFee, uint256 operationsFeeAmount, uint256 rewardFeeAmount) = _calculateFees(amount);

		if (from != address(PancakePair) && !_swapActive && swapEnabled) {
			_swapTokens();
		}

		if (_shouldTakeFee(from, to) && feesEnabled) {
			uint256 transferAmount = amount - totalFee;

			super._transfer(from, to, transferAmount);
			if (operationsFeeAmount > 0) {
				super._transfer(from, address(this), operationsFeeAmount);
			}
			if (rewardFeeAmount > 0) {
				super._transfer(from, address(_rewardsVault), rewardFeeAmount);
			}
		} else {
			super._transfer(from, to, amount);
		}
	}

	/// @dev Calculate amount of a value that should go to liquidity
	/// @param amount The original fee amount
	/// @return The value of fee to add to liquidity
	function _calculateLiquidityPercentage(uint256 amount) internal view returns (uint256) {
		return amount * feeLiquidityPercentage / 10e2;
	}

	/// @dev Calculate operations fee split amounts for liquidity tokens and total to swap to native
	/// @param amount The operations fee amount
	/// @return tokensForLiquidity The amount of tokens to save to pair with native currency for LP
	/// @return swapAmount The amount of tokens to swap for native currency to split for marketing and to pair for LP
	function _calculateOperationsFeeSplit(uint256 amount) 
		internal
		view
		returns (
			uint256 tokensForLiquidity,
			uint256 swapAmount
		)
	{
		// Get token amount from taxes for liquidity
		tokensForLiquidity = _calculateLiquidityPercentage(amount);
		// Get token amount from taxes for operations
		uint256 tokensForOperations = amount - tokensForLiquidity;
		// Halve liquidity tokens for converting to native
		uint256 liquidityTokens = tokensForLiquidity / 2;
		uint256 liquiditySwap = tokensForLiquidity - liquidityTokens;
		// Get total tokens to convert to native token
		swapAmount = tokensForOperations + liquiditySwap;
	}

	/// @dev If swapThreshold reached, swap tokens to native currency, add liquidity, and send to marketing wallet
	function _swapTokens() internal swapSemaphore {
		uint256 contractBalance = IERC20(address(this)).balanceOf(address(this));
		uint256 threshold = swapThreshold;
		if (contractBalance > threshold && swapEnabled) {
			if (threshold > maxTxAmount) {
				threshold = maxTxAmount;
			}

			(uint256 tokensForLiquidity, uint256 swapAmount) = _calculateOperationsFeeSplit(threshold);

			// Perform swap and calculate converted value
			uint256 initialBalance = payable(this).balance;
			_swapTokensForNative(swapAmount);
			uint256 swapBalance = payable(this).balance;
			uint256 profit = swapBalance - initialBalance;

			// Get native amount from taxes for liquidity/operations
			uint256 nativeForLiquidity = _calculateLiquidityPercentage(profit);
			uint256 nativeForOperations = profit - nativeForLiquidity;
			if (nativeForOperations > 0) {
				_withdrawNative(_operationsWallet, nativeForOperations);
			}
			if (nativeForLiquidity > 0) {
				_addLiquidity(tokensForLiquidity, nativeForLiquidity);
			}
		}
	}

	/// @dev Withdraw native currency to recipient using call method
	function _withdrawNative(address recipient, uint256 amount) internal virtual returns (bool success) {
		(success,) = payable(recipient).call{value: amount}("");
	}

	/// @dev Swap tokens for native currency (e.g. BNB)
	function _swapTokensForNative(uint256 amount) internal virtual {
		address[] memory path = new address[](2);
		path[0] = address(this);
		path[1] = PancakeRouter.WETH();
		_approve(address(this), address(PancakeRouter), amount);
		PancakeRouter.swapExactTokensForETH(amount, 0, path, address(this), block.timestamp);
		emit SwapTokensForNative(amount);
	}

	/// @dev Add liquidity to token from token contract holdings
	function _addLiquidity(uint256 tokenAmount, uint256 nativeAmount) private {
		_approve(address(this), address(PancakeRouter), tokenAmount);
		PancakeRouter.addLiquidityETH{value: nativeAmount}(address(this), tokenAmount, 0, 0, _liquidityRecipient, block.timestamp);
		emit AddLiquidity(tokenAmount, nativeAmount);
	}
}
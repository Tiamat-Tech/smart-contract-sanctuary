// SPDX-License-Identifier: UNLICENCED
pragma solidity >=0.6.12;

import './uniswapv2/UniswapV2Pair.sol';
import './uniswapv2/UniswapV2ERC20.sol';
import './uniswapv2/interfaces/IERC20.sol';
import './uniswapv2/interfaces/IUniswapV2Factory.sol';
import './starkex/interfaces/IStarkEx.sol';
import './uniswapv2/libraries/SafeMath.sol';

contract PairWithL2Overlay is UniswapV2Pair {
  using SafeMathUniswap for uint;
  uint internal constant quantom = 10000000000;
  uint internal constant delay = 1 days;
  uint public totalLoans;
  uint nonce;

  struct Withdrawal {
    uint amount;
    uint time;
  }

  mapping(address => Withdrawal) public delayedTransfers;
  bool public isLayer2Live;

  event QueuedWithdrawal(address indexed from, uint value, uint indexed time, uint indexed deadline);
  event FlashMint(uint amount, uint quantizedAmount);

  // Used to convey errors when enough balance requirement is not met
  error InsufficientBalance(uint256 available, uint256 required);

  modifier l2OperatorOnly() {
    if(isLayer2Live) {
      requireOperator();
    }
    _;
  }

  modifier l2Only() {
    require(isLayer2Live, 'DVF: ONLY_IN_LAYER2');
    _;
  }

  modifier operatorOnly() {
    requireOperator();
    _;
  }

  function getStarkEx() internal view returns (IStarkEx) {
    return IStarkEx(IUniswapV2Factory(factory).starkExContract());
  }

  function getStarkExRegistry(IStarkEx starkEx) internal returns (IStarkEx) {
    return IStarkEx(starkEx.orderRegistryAddress());
  }

  function requireOperator() internal view {
    require(isOperator(), 'L2_TRADING_ONLY');
  }

  function isOperator() internal view returns(bool) {
    return IUniswapV2Factory(factory).operators(tx.origin);
  }

  function flashMint(
    uint assetId, 
    uint quantisedAmount,
    uint tokenAssetId,
    uint tokenAmount,
    uint tokenBAssetId,
    uint tokenBAmount,
    address exchangeAddress) external operatorOnly l2Only returns(bool) {
    require(!isLocked(), "DVF: LOCK_IN_PROGRESS");
    // We mint on the pair itself
    // Then deposit into starkEx valut
    IStarkEx starkEx = getStarkEx();
    { // Stack too deep prevention
    uint amount = fromQuantized(quantom, quantisedAmount);
    _mint(address(this), amount);
    totalLoans = amount;
    // Lock the contract so no operations can proceed
    setLock(true);
    // Once it has been deployed
    // now create L1 limit order
    // Must allow starkEx contract to transfer the tokens from this pair
    _approve(address(this), IUniswapV2Factory(factory).starkExContract(), amount);

    emit FlashMint(amount, quantisedAmount);
    }
    starkEx.depositERC20ToVault(assetId, 0, quantisedAmount);

    // No native bit shifting available in EVM hence divison is fine

    // Reassigning to registry, no new variables to limit stack
    uint amountA = quantisedAmount / 2;
    uint amountB = quantisedAmount - amountA;
    uint nonceLocal = nonce; // gas savings
    starkEx = getStarkExRegistry(starkEx);
    // Verify the ratio
    starkEx.registerLimitOrder(exchangeAddress, assetId, tokenAssetId,
    tokenAssetId, amountA, tokenAmount, 0, 0, 0, 0, nonceLocal++, type(uint).max);

    starkEx.registerLimitOrder(exchangeAddress, assetId, tokenBAssetId,
    tokenBAssetId, amountB, tokenBAmount, 0, 0, 0, 0, nonceLocal++, type(uint).max);

    nonce = nonceLocal;

    return true;
  }

  function settleLoans(uint pairAssetId, uint tokenAssetId, uint tokenBAssetId) external operatorOnly returns(bool) {
    IStarkEx starkEx = getStarkEx();
    // must somehow clear all pending limit orders as well
    uint balance0 = starkEx.getQuantizedVaultBalance(address(this), tokenAssetId, 0);
    uint balance1 = starkEx.getQuantizedVaultBalance(address(this), tokenBAssetId, 0);
    starkEx.withdrawFromVault(tokenAssetId, 0, balance0);
    starkEx.withdrawFromVault(tokenBAssetId, 0, balance1);
    {
      // Withdraw left over LP and burn
      // withdraw from vault into this address and then burn it
      uint pairBalance = starkEx.getQuantizedVaultBalance(address(this), pairAssetId, 0);
      starkEx.withdrawFromVault(pairAssetId, 0, pairBalance);
      uint contractBalance = balanceOf[address(this)];
      if (contractBalance > 0) {
        totalLoans -= contractBalance;
        _burn(address(this), contractBalance);
      }
    }

    // Ensure we received the expected ratio matching totalLoans
    { // block to avoid stack limit exceptions
      (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
      balance0 = IERC20Uniswap(token0).balanceOf(address(this));
      balance1 = IERC20Uniswap(token1).balanceOf(address(this));
      uint amount0 = balance0.sub(_reserve0);
      uint amount1 = balance1.sub(_reserve1);
      uint _totalSupply = totalSupply;
      uint liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
      // require(liquidity >= totalLoans, "DVF: INSUFFICIENT_BALANCE_TO_SETTLE");
      if(liquidity < totalLoans) {
        revert InsufficientBalance({
          available: totalLoans,
          required: liquidity
        });
      }
    }

    totalLoans = 0;
    setLock(false);
    sync();
    return true;
  }

  /**
   * Allow clearing vaults by pulling all funds out, can only be used by the operator in L2
   * Should not be required if all operations are performing correctly
  */
  function withdrawAllFromVault(uint assetId) external l2OperatorOnly {
    uint balance = getStarkEx().getQuantizedVaultBalance(address(this), assetId, 0);
    getStarkEx().withdrawFromVault(assetId, 0, balance);
  }

  function withdrawAndClearLoans(uint assetId) external l2OperatorOnly {
    require(totalLoans > 0, "DVF: NO_OUTSTANDING_LOANS");
    getStarkEx().withdrawFromVault(assetId, 0, toQuantized(quantom, totalLoans));
    clearLoans();
  }

  // Clear all loans by expecting the loaned tokens to be depossited back in
  function clearLoans() public l2OperatorOnly {
    require(totalLoans > 0, "DVF: NO_OUTSTANDING_LOANS");
    uint balance = balanceOf[address(this)];
    require(balance >= totalLoans, "DVF: NOT_ENOUGH_LP_DEPOSITTED");
    _burn(address(this), balance);
    setLock(false);
    totalLoans = 0;
  }

  /**
   * Restrict for L2
  */
  function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) public override l2OperatorOnly {
    super.swap(amount0Out, amount1Out, to, data);
  }

  function mint(address to) public override l2OperatorOnly returns (uint liquidity) {
    return super.mint(to);
  }

  /**
  * @dev Transfer your tokens
  * For burning tokens transfers are done to this contact address first and they must be queued in L2 `queueBurnDirect`
  * User to User transfers follow standard ERC-20 pattern
  */
  function transfer(address to, uint value) public override returns (bool) { 
    require(!(isLayer2Live && !isOperator() && to == address(this)), "DVF_AMM: CANNOT_MINT_L2");

    require(super.transfer(to, value), "DVF_AMM: TRANSFER_FAILED");
    return true;
  }

  /**
  * @dev Transfer approved tokens
  * For burning tokens transfers are done to this contact address first and they must be queued in L2 `queueBurn`
  * User to User transfers follow standard ERC-20 pattern
  */
  function transferFrom(address from, address to, uint value) public override returns (bool) {
    require(!(isLayer2Live && !isOperator() && to == address(this)), "DVF_AMM: CANNOT_MINT_L2");

    require(super.transferFrom(from, to, value), "DVF_AMM: TRANSFER_FAILED");
    return true;
  }

  function _validateDelayedTransfers(uint time, uint amount, uint value) private view {
    require(time <= block.timestamp, "DVF_AMM: TOO_EARLY");
    require(time > block.timestamp - delay, "DVF_AMM: TOO_LATE");
    require(amount >= value, "DVF_AMM: REQUEST_LARGER_THAN_EXPECTATION");
  }

  function _queueBurn(uint value, address from) private returns (uint) {
    require(isLayer2Live, "DVF_AMM: L1_NOT_REQUIRED");
    require(balanceOf[from] >= value, "DVF_AMM: INSUFFICIENT_BALANCE");
    Withdrawal storage w = delayedTransfers[from];
    uint time = block.timestamp + delay; // gas saving
    uint deadline = time + delay; 
    w.time = time;
    w.amount = value;
    emit QueuedWithdrawal(from, value, time, deadline);

    return time;
  }

  function skim(address to) public override l2OperatorOnly {
    super.skim(to);
  }

  function sync() public override l2OperatorOnly {
    super.sync();
  }

  function activateLayer2(bool _isLayer2Live) external operatorOnly {
    if (_isLayer2Live) {
      require(!IUniswapV2Factory(factory).isStarkExContractFrozen(), 'DVF_AMM: STARKEX_FROZEN');
    }
    isLayer2Live = _isLayer2Live;
  }

  function emergencyDisableLayer2() public {
    require(isLayer2Live, 'DVF_AMM: LAYER2_ALREADY_DISABLED');
    require(IUniswapV2Factory(factory).isStarkExContractFrozen(), 'DVF_AMM: STARKEX_NOT_FROZEN');
    isLayer2Live = false;
    setLock(false);
  }

  function fromQuantized(uint quantum, uint256 quantizedAmount)
      public pure returns (uint256 amount) {
      amount = quantizedAmount * quantum;
      require(amount / quantum == quantizedAmount, "DEQUANTIZATION_OVERFLOW");
  }


  function toQuantized(uint quantum, uint256 amount)
      public pure returns (uint256 quantizedAmount) {
      require(amount % quantum == 0, "INVALID_AMOUNT");
      quantizedAmount = amount / quantum;
  }
}
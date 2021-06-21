//SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../interface/IStrategy.sol";
import "../interface/ISmartVault.sol";
import "../interface/IController.sol";
import "../interface/IUpgradeSource.sol";
import "../interface/ISmartVault.sol";
import "./VaultStorage.sol";
import "../governance/Controllable.sol";
import "../interface/IBookkeeper.sol";

/**
Use number error codes for reducing the contract size:
100 - _toInvestNumerator is higher then _toInvestDenominator in initializeSmartVault
101 - _toInvestDenominator must not be zero
102 - strategy no defined
104 - only for addresses included in reward distribution
105 - the strategy exists and switch timelock did not elapse yet
106 - new strategy cannot be empty
107 - vault underlying must match Strategy underlying
108 - the strategy does not belong to this vault
109 - new denominator must be greater than 0
110 - new denominator must be greater than or equal to the numerator
111 - Reward token already exists
112 - Reward token does not exists
113 - Can only remove when the reward period has passed
114 - Cannot remove the last reward token
115 - the notified reward cannot invoke multiplication overflow
116 - rewardTokenIndex not found
117 - Vault has no shares
118 - numberOfShares must be greater than 0
119 - Cannot deposit 0
120 - holder must be defined
121 - Too much arb
122 - Share price should not decrease
123 - Vault deactivated
124 - Reward token should not be equal underlying
*/
contract SmartVault is Initializable, ERC20Upgradeable, VaultStorage, IUpgradeSource, Controllable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using SafeMathUpgradeable for uint256;

  // ************* CONSTANTS ********************
  string public constant VERSION = "0";

  // ********************* VARIABLES *****************
  //in upgradable contracts you can skip storage ONLY for mapping and dynamically-sized array types
  //https://docs.soliditylang.org/en/v0.4.21/miscellaneous.html#layout-of-state-variables-in-storage
  //use VaultStorage for primitive variables
  address[] internal _rewardTokens;
  mapping(address => uint256) public periodFinishForToken;
  mapping(address => uint256) public rewardRateForToken;
  mapping(address => uint256) public lastUpdateTimeForToken;
  mapping(address => uint256) public rewardPerTokenStoredForToken;
  mapping(address => mapping(address => uint256)) public userRewardPerTokenPaidForToken;
  mapping(address => mapping(address => uint256)) public rewardsForToken;

  function initializeSmartVault(
    string memory _name,
    string memory _symbol,
    address _controller,
    address _underlying,
    uint256 _toInvestNumerator,
    uint256 _toInvestDenominator,
    uint256 _duration
  ) public initializer {
    require(_toInvestNumerator <= _toInvestDenominator, "100");
    require(_toInvestDenominator != 0, "101");

    __ERC20_init(_name, _symbol);
    //    _setupDecimals(ERC20Upgradeable(_underlying).decimals());

    Controllable.initializeControllable(_controller);
    VaultStorage.initializeVaultStorage(
      _underlying,
      _toInvestNumerator,
      _toInvestDenominator,
      10 ** uint256(ERC20Upgradeable(address(_underlying)).decimals()),
      24 hours,
      24 hours,
      _duration
    );
  }

  // *************** EVENTS ***************************
  event Withdraw(address indexed beneficiary, uint256 amount);
  event Deposit(address indexed beneficiary, uint256 amount);
  event Invest(uint256 amount);
  event StrategyAnnounced(address newStrategy, uint256 time);
  event StrategyChanged(address newStrategy, address oldStrategy);
  event RewardAdded(address rewardToken, uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, address rewardToken, uint256 reward);
  event RewardDenied(address indexed user, address rewardToken, uint256 reward);
  event AddedRewardToken(address indexed token);
  event RemovedRewardToken(address indexed token);

  function decimals() public view override returns (uint8) {
    return ERC20Upgradeable(underlying()).decimals();
  }


  // *************** MODIFIERS ***************************

  /**
   *  Strategy should not be a zero address
   */
  modifier whenStrategyDefined() {
    require(address(strategy()) != address(0), "102");
    _;
  }

  modifier isActive() {
    require(active(), "123");
    _;
  }

  // ************ GOVERNANCE ACTIONS ******************

  /**
   * Change the active state marker
   */
  function changeActivityStatus(bool active) external onlyGovernance {
    _setActive(active);
  }

  /**
   * Chooses the best strategy and re-invests. If the strategy did not change, it just calls
   * doHardWork on the current strategy. Call this through controller to claim hard rewards.
   */
  function doHardWork() external whenStrategyDefined onlyControllerOrGovernance isActive override {
    uint256 sharePriceBeforeHardWork = getPricePerFullShare();
    if (withdrawBeforeReinvesting()) {
      IStrategy(strategy()).withdrawAllToVault();
    }
    // ensure that new funds are invested too
    invest();
    IStrategy(strategy()).doHardWork();
    if (!allowSharePriceDecrease()) {
      require(sharePriceBeforeHardWork <= getPricePerFullShare(), "122");
    }
  }

  /**
   * Change the vault fraction to invest
   */
  function setVaultFractionToInvest(uint256 numerator, uint256 denominator) external onlyGovernance {
    require(denominator > 0, "109");
    require(numerator <= denominator, "110");
    _setVaultFractionToInvestNumerator(numerator);
    _setVaultFractionToInvestDenominator(denominator);
    // we have an event in the vault storage
  }

  /**
   * A push mechanism for accounts that have not claimed their rewards for a long time.
   * The implementation is semantically analogous to getReward(), but uses a push pattern
   * instead of pull pattern.
   */
  function pushAllRewards(address recipient) public onlyGovernance {
    updateRewards(recipient);
    for (uint256 i = 0; i < _rewardTokens.length; i++) {
      uint256 reward = earned(_rewardTokens[i], recipient);
      if (reward > 0) {
        rewardsForToken[_rewardTokens[i]][recipient] = 0;
        IERC20Upgradeable(_rewardTokens[i]).safeTransfer(recipient, reward);
        emit RewardPaid(recipient, _rewardTokens[i], reward);
      }
    }
  }

  /**
   * Add a reward token to the internal array
   */
  function addRewardToken(address rt) public onlyGovernance {
    require(getRewardTokenIndex(rt) == uint256(- 1), "111");
    require(rt != underlying(), "124");
    _rewardTokens.push(rt);
    emit AddedRewardToken(rt);
  }

  /**
   * Remove reward token. Last token removal is not allowed
   */
  function removeRewardToken(address rt) public onlyGovernance {
    uint256 i = getRewardTokenIndex(rt);
    require(i != uint256(- 1), "112");
    require(periodFinishForToken[_rewardTokens[i]] < block.timestamp, "113");
    require(_rewardTokens.length > 1, "114");
    uint256 lastIndex = _rewardTokens.length - 1;
    // swap
    _rewardTokens[i] = _rewardTokens[lastIndex];
    // delete last element
    _rewardTokens.pop();
    emit RemovedRewardToken(rt);
  }

  /**
   * Withdraw all from strategy to the vault and invest again
   */
  function rebalance() external onlyGovernance {
    withdrawAllToVault();
    invest();
  }

  /**
   * Withdraw all from strategy to the vault
   */
  function withdrawAllToVault() public onlyGovernance whenStrategyDefined {
    IStrategy(strategy()).withdrawAllToVault();
  }

  //****************** USER ACTIONS ********************

  /**
   * Allows for depositing the underlying asset in exchange for shares.
   * Approval is assumed.
   */
  function deposit(uint256 amount) external override onlyAllowedUsers isActive {
    _deposit(amount, msg.sender, msg.sender);
  }

  /**
   * Allows for depositing the underlying asset in exchange for shares.
   * Approval is assumed. Immediately invests the asset to the strategy
   */
  function depositAndInvest(uint256 amount) external override onlyAllowedUsers isActive {
    _deposit(amount, msg.sender, msg.sender);
    invest();
  }

  /**
   * Allows for depositing the underlying asset in exchange for shares
   * assigned to the holder.
   * This facilitates depositing for someone else (using DepositHelper)
   */
  function depositFor(uint256 amount, address holder) public override onlyAllowedUsers isActive {
    _deposit(amount, msg.sender, holder);
  }

  /**
   * Withdraw shares partially without touching rewards
   */
  function withdraw(uint256 numberOfShares) external override onlyAllowedUsers {
    _withdraw(numberOfShares);
  }

  /**
   * Withdraw all and claim rewards
   */
  function exit() external override onlyAllowedUsers {
    _withdraw(balanceOf(msg.sender));
    getAllRewards();
  }

  /**
   * Update and Claim all rewards
   */
  function getAllRewards() public override onlyAllowedUsers {
    updateRewards(msg.sender);
    for (uint256 i = 0; i < _rewardTokens.length; i++) {
      _payReward(_rewardTokens[i]);
    }
  }

  /**
   *  Update and Claim rewards for specific token
   */
  function getReward(address rt) public override onlyAllowedUsers {
    updateReward(msg.sender, rt);
    _payReward(rt);
  }

  //**************** UNDERLYING MANAGEMENT FUNCTIONALITY ***********************

  /*
   * Returns the cash balance across all users in this contract.
   */
  function underlyingBalanceInVault() public view override returns (uint256) {
    return IERC20Upgradeable(underlying()).balanceOf(address(this));
  }

  /* Returns the current underlying (e.g., DAI's) balance together with
   * the invested amount (if DAI is invested elsewhere by the strategy).
   */
  function underlyingBalanceWithInvestment() public view override returns (uint256) {
    if (address(strategy()) == address(0)) {
      // initial state, when not set
      return underlyingBalanceInVault();
    }
    return underlyingBalanceInVault()
    .add(IStrategy(strategy()).investedUnderlyingBalance());
  }

  /**
   * Get the user's share (in underlying)
   * underlyingBalanceWithInvestment() * balanceOf(holder) / totalSupply()
   */
  function underlyingBalanceWithInvestmentForHolder(address holder)
  external view returns (uint256) {
    if (totalSupply() == 0) {
      return 0;
    }
    return underlyingBalanceWithInvestment()
    .mul(balanceOf(holder))
    .div(totalSupply());
  }

  /**
   * Price per full share (PPFS)
   * Vaults with 100% buybacks have a value of 1 constantly
   * (underlyingUnit() * underlyingBalanceWithInvestment()) / totalSupply()
   */
  function getPricePerFullShare() public view override returns (uint256) {
    return totalSupply() == 0
    ? underlyingUnit()
    : underlyingUnit().mul(underlyingBalanceWithInvestment()).div(totalSupply());
  }

  /**
   * Return amount of the underlying asset ready to invest to the strategy
   * (underlyingBalanceWithInvestment() * vaultFractionToInvestNumerator()
   *              * vaultFractionToInvestDenominator()) - alreadyInvested
   */
  function availableToInvestOut() public view override returns (uint256) {
    uint256 wantInvestInTotal = underlyingBalanceWithInvestment()
    .mul(vaultFractionToInvestNumerator())
    .div(vaultFractionToInvestDenominator());
    uint256 alreadyInvested = IStrategy(strategy()).investedUnderlyingBalance();
    if (alreadyInvested >= wantInvestInTotal) {
      return 0;
    } else {
      uint256 remainingToInvest = wantInvestInTotal.sub(alreadyInvested);
      return remainingToInvest <= underlyingBalanceInVault()
      ? remainingToInvest : underlyingBalanceInVault();
    }
  }

  /**
   * Burn shares, withdraw underlying from strategy
   * and send back to the user the underlying asset
   */
  function _withdraw(uint256 numberOfShares) internal {
    require(totalSupply() > 0, "117");
    require(numberOfShares > 0, "118");
    uint256 totalSupply = totalSupply();
    _burn(msg.sender, numberOfShares);

    // only statistic, no funds affected
    try IBookkeeper(IController(controller()).bookkeeper())
    .registerUserAction(msg.sender, numberOfShares, false) {
    } catch {}

    uint256 underlyingAmountToWithdraw = underlyingBalanceWithInvestment()
    .mul(numberOfShares)
    .div(totalSupply);
    if (underlyingAmountToWithdraw > underlyingBalanceInVault()) {
      // withdraw everything from the strategy to accurately check the share value
      if (numberOfShares == totalSupply) {
        IStrategy(strategy()).withdrawAllToVault();
      } else {
        uint256 missing = underlyingAmountToWithdraw.sub(underlyingBalanceInVault());
        IStrategy(strategy()).withdrawToVault(missing);
      }
      // recalculate to improve accuracy
      underlyingAmountToWithdraw = MathUpgradeable.min(underlyingBalanceWithInvestment()
      .mul(numberOfShares)
      .div(totalSupply), underlyingBalanceInVault());
    }

    IERC20Upgradeable(underlying()).safeTransfer(msg.sender, underlyingAmountToWithdraw);

    // update the withdrawal amount for the holder
    emit Withdraw(msg.sender, underlyingAmountToWithdraw);
  }

  /**
   * Mint shares and transfer underlying from user to the vault
   * New shares = (invested amount * total supply) / underlyingBalanceWithInvestment()
   */
  function _deposit(uint256 amount, address sender, address beneficiary) internal {
    require(amount > 0, "119");
    require(beneficiary != address(0), "120");

    uint256 toMint = totalSupply() == 0
    ? amount
    : amount.mul(totalSupply()).div(underlyingBalanceWithInvestment());
    _mint(beneficiary, toMint);

    IERC20Upgradeable(underlying()).safeTransferFrom(sender, address(this), amount);

    // only statistic, no funds affected
    IBookkeeper(IController(controller()).bookkeeper())
    .registerUserAction(beneficiary, toMint, true);

    emit Deposit(beneficiary, amount);
  }

  /**
   * Transfer underlying to the strategy
   */
  function invest() internal whenStrategyDefined {
    uint256 availableAmount = availableToInvestOut();
    if (availableAmount > 0) {
      IERC20Upgradeable(underlying()).safeTransfer(address(strategy()), availableAmount);
      IStrategy(strategy()).investAllUnderlying();
      emit Invest(availableAmount);
    }
  }

  //**************** REWARDS FUNCTIONALITY ***********************

  /**
   *  Return earned rewards for specific token and account
   *  Accurate value returns only after updateRewards call (when somebody withdraw)
   *  ((balanceOf(account)
   *    * (rewardPerToken - userRewardPerTokenPaidForToken)) / 10**18) + rewardsForToken
   */
  function earned(address rt, address account) public view override returns (uint256) {
    return
    balanceOf(account)
    .mul(rewardPerToken(rt).sub(userRewardPerTokenPaidForToken[rt][account]))
    .div(1e18)
    .add(rewardsForToken[rt][account]);
  }

  /**
   * Return reward per token ratio by reward token address
   * rewardPerTokenStoredForToken + (
   * (lastTimeRewardApplicable - lastUpdateTimeForToken) * rewardRateForToken * 10**18 / totalSupply)
   */
  function rewardPerToken(address rt) public view override returns (uint256) {
    if (totalSupply() == 0) {
      return rewardPerTokenStoredForToken[rt];
    }
    return
    rewardPerTokenStoredForToken[rt].add(
      lastTimeRewardApplicable(rt)
      .sub(lastUpdateTimeForToken[rt])
      .mul(rewardRateForToken[rt])
      .mul(1e18)
      .div(totalSupply())
    );
  }

  /**
   * Return periodFinishForToken or block.timestamp by reward token address
   */
  function lastTimeRewardApplicable(address rt) public view override returns (uint256) {
    return MathUpgradeable.min(block.timestamp, periodFinishForToken[rt]);
  }

  /**
   * Return reward token array length
   */
  function rewardTokens() public view override returns (address[] memory){
    return _rewardTokens;
  }

  /**
   * Return reward token array length
   */
  function rewardTokensLength() public view override returns (uint256){
    return _rewardTokens.length;
  }

  /**
   * Return reward token index
   * If the return value is MAX_UINT256, it means that
   * the specified reward token is not in the list
   */
  function getRewardTokenIndex(address rt) public override view returns (uint256) {
    for (uint i = 0; i < _rewardTokens.length; i++) {
      if (_rewardTokens[i] == rt)
        return i;
    }
    return uint256(- 1);
  }

  /**
   * Update rewardRateForToken
   * If period ended: reward / duration
   * else add leftover to the reward amount and refresh the period
   * (reward + ((periodFinishForToken - block.timestamp) * rewardRateForToken)) / duration
   */
  function notifyTargetRewardAmount(address _rewardToken, uint256 reward)
  public override
  onlyRewardDistribution
  {
    updateRewards(address(0));
    // overflow fix according to https://sips.synthetix.io/sips/sip-77
    require(reward < uint(- 1) / 1e18, "115");

    uint256 i = getRewardTokenIndex(_rewardToken);
    require(i != uint256(- 1), "116");

    if (block.timestamp >= periodFinishForToken[_rewardToken]) {
      rewardRateForToken[_rewardToken] = reward.div(duration());
    } else {
      uint256 remaining = periodFinishForToken[_rewardToken].sub(block.timestamp);
      uint256 leftover = remaining.mul(rewardRateForToken[_rewardToken]);
      rewardRateForToken[_rewardToken] = reward.add(leftover).div(duration());
    }
    lastUpdateTimeForToken[_rewardToken] = block.timestamp;
    periodFinishForToken[_rewardToken] = block.timestamp.add(duration());
    emit RewardAdded(_rewardToken, reward);
  }

  /**
   * Transfer earned rewards to caller
   */
  function _payReward(address rt) internal {
    uint256 reward = earned(rt, msg.sender);
    if (reward > 0 && IERC20Upgradeable(rt).balanceOf(address(this)) >= reward) {
      rewardsForToken[rt][msg.sender] = 0;
      IERC20Upgradeable(rt).safeTransfer(msg.sender, reward);
      emit RewardPaid(msg.sender, rt, reward);
    }
  }

  /**
   * Update account rewards for each reward token
   */
  function updateRewards(address account) public {
    for (uint256 i = 0; i < _rewardTokens.length; i++) {
      address rt = _rewardTokens[i];
      updateReward(account, rt);
    }
  }

  /**
   * Update reward data for given account and reward token
   */
  function updateReward(address account, address rt) internal {
    rewardPerTokenStoredForToken[rt] = rewardPerToken(rt);
    lastUpdateTimeForToken[rt] = lastTimeRewardApplicable(rt);
    if (account != address(0)) {
      rewardsForToken[rt][account] = earned(rt, account);
      userRewardPerTokenPaidForToken[rt][account] = rewardPerTokenStoredForToken[rt];
    }
  }

  //**************** VAULT UPDATE FUNCTIONALITY ***********************

  /**
   * Schedules an upgrade for this vault's proxy.
   */
  function scheduleUpgrade(address impl) public onlyGovernance {
    _setNextImplementation(impl);
    _setNextImplementationTimestamp(block.timestamp.add(nextImplementationDelay()));
  }

  /**
   *  Finalizes (or cancels) the vault update by resetting the data
   */
  function finalizeUpgrade() external override onlyGovernance {
    _setNextImplementation(address(0));
    _setNextImplementationTimestamp(0);
  }

  /**
   * Return ready state for the vault update and next implementation address
   * Use it in a proxy contract for checking availability to update this contract
   */
  function shouldUpgrade() external view override returns (bool, address) {
    return (
    nextImplementationTimestamp() != 0
    && block.timestamp > nextImplementationTimestamp()
    && nextImplementation() != address(0),
    nextImplementation()
    );
  }

  //**************** STRATEGY UPDATE FUNCTIONALITY ***********************

  /**
   * Return ready state for the strategy update
   */
  function canUpdateStrategy(address _strategy) public view override returns (bool) {
    return strategy() == address(0) // no strategy was set yet
    || (_strategy == futureStrategy() // or the timelock has passed
    && block.timestamp > strategyUpdateTime()
    && strategyUpdateTime() > 0);
  }

  /**
   * Indicates that the strategy update will happen in the future
   */
  function announceStrategyUpdate(address _strategy) public onlyControllerOrGovernance {
    // records a new timestamp
    uint256 when = block.timestamp.add(strategyTimeLock());
    _setStrategyUpdateTime(when);
    _setFutureStrategy(_strategy);
    emit StrategyAnnounced(_strategy, when);
  }

  /**
   * Finalizes (or cancels) the strategy update by resetting the data
   */
  function finalizeStrategyUpdate() public onlyControllerOrGovernance {
    _setStrategyUpdateTime(0);
    _setFutureStrategy(address(0));
  }

  /**
   * Check the strategy time lock, withdraw all to the vault and change the strategy
   * Should be called via controller
   */
  function setStrategy(address _strategy) public override onlyControllerOrGovernance {
    require(canUpdateStrategy(_strategy), "105");
    require(_strategy != address(0), "106");
    require(IStrategy(_strategy).underlying() == address(underlying()), "107");
    require(IStrategy(_strategy).vault() == address(this), "108");

    emit StrategyChanged(_strategy, strategy());
    if (address(_strategy) != address(strategy())) {
      if (address(strategy()) != address(0)) {// if the original strategy (no underscore) is defined
        IERC20Upgradeable(underlying()).safeApprove(address(strategy()), 0);
        IStrategy(strategy()).withdrawAllToVault();
      }
      _setStrategy(_strategy);
      IERC20Upgradeable(underlying()).safeApprove(address(strategy()), 0);
      IERC20Upgradeable(underlying()).safeApprove(address(strategy()), uint256(~0));
    }
    finalizeStrategyUpdate();
  }

}
// SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interface/IStrategy.sol";
import "../interface/ISmartVault.sol";
import "../interface/IFeeRewardForwarder.sol";
import "./Controllable.sol";
import "../interface/IBookkeeper.sol";
import "./ControllerStorage.sol";

contract Controller is Initializable, Controllable, ControllerStorage {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  function initialize() public initializer {
    Controllable.initializeControllable(address(this));
    ControllerStorage.initializeControllerStorage(
      msg.sender
    );

    setPSNumeratorDenominator(1000, 1000);
  }

  // ************ EVENTS **********************

  event HardWorkerAdded(address value);
  event HardWorkerRemoved(address value);
  event AddedToWhiteList(address value);
  event RemovedFromWhiteList(address value);
  event VaultAndStrategyAdded(address vault, address strategy);
  event Salvaged(address token, uint256 amount);
  event SalvagedStrategy(address strategy, address token, uint256 amount);
  event NotifyFee(address underlying, uint256 fee);
  event SharePriceChangeLog(
    address indexed vault,
    address indexed strategy,
    uint256 oldSharePrice,
    uint256 newSharePrice,
    uint256 timestamp
  );

  // ************ VARIABLES **********************
  string public constant VERSION = "0";
  mapping(address => bool) public override whiteList;
  mapping(address => bool) public override vaults;
  mapping(address => bool) public override strategies;
  mapping(address => bool) public hardWorkers;
  mapping(address => bool) public rewardDistribution;

  // ************ GOVERNANCE ACTIONS **************************

  function setGovernance(address _governance) external onlyGovernance {
    require(_governance != address(0), "zero address");
    _setGovernance(_governance);
  }

  function setFeeRewardForwarder(address _feeRewardForwarder) external onlyGovernance {
    require(_feeRewardForwarder != address(0), "zero address");
    rewardDistribution[feeRewardForwarder()] = false;
    _setFeeRewardForwarder(_feeRewardForwarder);
    rewardDistribution[feeRewardForwarder()] = true;
  }

  function setBookkeeper(address _bookkeeper) external onlyGovernance {
    require(_bookkeeper != address(0), "zero address");
    _setBookkeeper(_bookkeeper);
  }

  function setMintHelper(address _newValue) external onlyGovernance {
    require(_newValue != address(0), "zero address");
    _setMintHelper(_newValue);
  }

  function setRewardToken(address _newValue) external onlyGovernance {
    require(_newValue != address(0), "zero address");
    _setRewardToken(_newValue);
  }

  function setNotifyHelper(address _newValue) external onlyGovernance {
    require(_newValue != address(0), "zero address");
    rewardDistribution[notifyHelper()] = false;
    _setNotifyHelper(_newValue);
    rewardDistribution[notifyHelper()] = true;
  }

  function setPsVault(address _newValue) external onlyGovernance {
    require(_newValue != address(0), "zero address");
    _setPsVault(_newValue);
  }

  function setRewardDistribution(address[] calldata _newRewardDistribution, bool _flag) external onlyGovernance {
    for (uint256 i = 0; i < _newRewardDistribution.length; i++) {
      rewardDistribution[_newRewardDistribution[i]] = _flag;
    }
  }

  function setPSNumeratorDenominator(uint256 numerator, uint256 denominator) public onlyGovernance {
    require(numerator <= denominator, "invalid values");
    require(denominator != 0, "cannot divide by 0");
    _setPsNumerator(numerator);
    _setPsDenominator(denominator);
  }

  function addHardWorker(address _worker) external onlyGovernance {
    require(_worker != address(0), "_worker must be defined");
    hardWorkers[_worker] = true;
    emit HardWorkerAdded(_worker);
  }

  function removeHardWorker(address _worker) external onlyGovernance {
    require(_worker != address(0), "_worker must be defined");
    hardWorkers[_worker] = false;
    emit HardWorkerRemoved(_worker);
  }

  function addToWhiteList(address _target) external onlyGovernance {
    whiteList[_target] = true;
    emit AddedToWhiteList(_target);
  }

  function removeFromWhiteList(address _target) external onlyGovernance {
    whiteList[_target] = false;
    emit RemovedFromWhiteList(_target);
  }

  function addVaultAndStrategy(address _vault, address _strategy) external onlyGovernance {
    require(_vault != address(0), "new vault shouldn't be empty");
    require(!vaults[_vault], "vault already exists");
    // existed strategies allowed
    require(_strategy != address(0), "new strategy shouldn't be empty");

    vaults[_vault] = true;
    IBookkeeper(bookkeeper()).addVault(_vault);

    if (strategies[_strategy] == false) {
      strategies[_strategy] = true;
      IBookkeeper(bookkeeper()).addStrategy(_strategy);
    }

    // adding happens while setting
    ISmartVault(_vault).setStrategy(_strategy);
    emit VaultAndStrategyAdded(_vault, _strategy);
  }

  function doHardWork(address _vault) external onlyHardWorkerOrGovernance validVault(_vault) {
    uint256 oldSharePrice = ISmartVault(_vault).getPricePerFullShare();
    ISmartVault(_vault).doHardWork();
    emit SharePriceChangeLog(
      _vault,
      ISmartVault(_vault).strategy(),
      oldSharePrice,
      ISmartVault(_vault).getPricePerFullShare(),
      block.timestamp
    );
  }

  // transfers token in the controller contract to the governance
  function salvage(address _token, uint256 _amount) external onlyGovernance {
    IERC20(_token).safeTransfer(governance(), _amount);
    emit Salvaged(_token, _amount);
  }

  function salvageStrategy(address _strategy, address _token, uint256 _amount) external onlyGovernance {
    // the strategy is responsible for maintaining the list of
    // salvagable tokens, to make sure that governance cannot come
    // in and take away the coins
    IStrategy(_strategy).salvage(governance(), _token, _amount);
    emit SalvagedStrategy(_strategy, _token, _amount);
  }

  // ***************** EXTERNAL *******************************

  function isGovernance(address _adr) public view override returns (bool) {
    return governance() == _adr;
  }

  function isHardWorker(address _adr) public override view returns (bool) {
    return hardWorkers[_adr] || isGovernance(_adr);
  }

  function isRewardDistributor(address _adr) public override view returns (bool) {
    return rewardDistribution[_adr] || isGovernance(_adr);
  }

  function isAllowedUser(address _adr) external view override returns (bool) {
    return isNotSmartContract(_adr)
    || whiteList[_adr]
    || isGovernance(_adr)
    || isHardWorker(_adr)
    || isRewardDistributor(_adr)
    || vaults[_adr]
    || strategies[_adr];
  }

  // it is not 100% guarantee after EIP-3074 implementation
  // use it as an additional check
  function isNotSmartContract(address _adr) private view returns (bool) {
    return _adr == tx.origin;
  }

  function isValidVault(address _vault) external override view returns (bool) {
    return vaults[_vault];
  }
}
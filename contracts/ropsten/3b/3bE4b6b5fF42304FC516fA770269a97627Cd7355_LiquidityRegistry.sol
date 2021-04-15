// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./interfaces/IPolicyBook.sol";
import "./interfaces/IPolicyBookRegistry.sol";
import "./interfaces/IContractsRegistry.sol";
import "./interfaces/ILiquidityRegistry.sol";
import "./interfaces/IBMIDAIStaking.sol";

import "./abstract/AbstractDependant.sol";

contract LiquidityRegistry is ILiquidityRegistry, AbstractDependant {
  using SafeMath for uint256;
  using Math for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  IPolicyBookRegistry public policyBookRegistry;
  IBMIDAIStaking public bmiDaiStaking;

  // User address => policy books array
  mapping(address => EnumerableSet.AddressSet) private _policyBooks;

  event PolicyBookAdded(address _userAddr, address _policyBookAddress);
  event PolicyBookRemoved(address _userAddr, address _policyBookAddress);

  function setDependencies(IContractsRegistry _contractsRegistry) external override onlyInjectorOrZero { 
    policyBookRegistry = IPolicyBookRegistry(_contractsRegistry.getPolicyBookRegistryContract());
    bmiDaiStaking = IBMIDAIStaking(_contractsRegistry.getBMIDAIStakingContract());
  }

  modifier onlyEligibleContracts() {
    require(policyBookRegistry.isPolicyBook(msg.sender) || msg.sender == address(bmiDaiStaking),
      "LR: Not an eligible contract");
    _;
  }

  function tryToAddPolicyBook(address _userAddr, address _policyBookAddr) external override onlyEligibleContracts {
    if (IERC20(_policyBookAddr).balanceOf(_userAddr) > 0 || 
      bmiDaiStaking.balanceOf(_userAddr) > 0) {
      _policyBooks[_userAddr].add(_policyBookAddr);

      emit PolicyBookAdded(_userAddr, _policyBookAddr);
    }
  }

  function tryToRemovePolicyBook(address _userAddr, address _policyBookAddr) external override onlyEligibleContracts {
    if (IERC20(_policyBookAddr).balanceOf(_userAddr) == 0 &&
      bmiDaiStaking.balanceOf(_userAddr) == 0 &&
      IPolicyBook(_policyBookAddr).getWithdrawalStatus(_userAddr) == IPolicyBook.WithdrawalStatus.NONE) {
      _policyBooks[_userAddr].remove(_policyBookAddr);

      emit PolicyBookRemoved(_userAddr, _policyBookAddr);
    }
  }

  function getPolicyBooksArr(address _userAddr) external view returns (address[] memory _resultArr) {
    EnumerableSet.AddressSet storage policyBooksArr = _policyBooks[_userAddr];
    uint256 _policyBooksArrLength = policyBooksArr.length();

    _resultArr = new address[](_policyBooksArrLength);

    for (uint256 i = 0; i < _policyBooksArrLength; i++) {
      _resultArr[i] = policyBooksArr.at(i);
    }
  }

  function getLiquidityInfos(address _userAddr, uint256 _offset, uint256 _limit)
    external
    view
    returns (LiquidityInfo[] memory _resultArr)
  {
    EnumerableSet.AddressSet storage policyBooksArr = _policyBooks[_userAddr];

    uint256 _to = (_offset.add(_limit)).min(policyBooksArr.length()).max(_offset);

    _resultArr =  new LiquidityInfo[](_to - _offset);

    for (uint256 i = _offset; i < _to; i++) {
      address _currentPolicyBookAddr = policyBooksArr.at(i);

      (uint256 _lockedAmount, ) = IPolicyBook(_currentPolicyBookAddr).withdrawalsInfo(_userAddr);
      uint256 _availableAmount = IERC20(address(_currentPolicyBookAddr)).balanceOf(_userAddr);

      _resultArr[i] = LiquidityInfo(_currentPolicyBookAddr, _lockedAmount, _availableAmount, 0, 0, 0);

      if (IPolicyBook(_currentPolicyBookAddr).whitelisted()) {
        _resultArr[i].stakedAmount = bmiDaiStaking.totalStaked(_userAddr, address(_currentPolicyBookAddr));
        _resultArr[i].rewardsAmount = _getBMIProfit(_userAddr, _currentPolicyBookAddr);
        _resultArr[i].apy = bmiDaiStaking.getPolicyBookAPY(_currentPolicyBookAddr);
      }
    }
  }

  function _getBMIProfit(address _userAddr, address _policyBookAddr) internal view returns (uint256) {
    return bmiDaiStaking.getStakerBMIProfit(_userAddr, _policyBookAddr, 0, bmiDaiStaking.balanceOf(_userAddr));
  }

  function getWithdrawalRequests(address _userAddr, uint256 _offset, uint256 _limit)
    external
    view
    returns (uint256 _arrLength, WithdrawalRequestInfo[] memory _resultArr)
  {
    EnumerableSet.AddressSet storage policyBooksArr = _policyBooks[_userAddr];

    uint256 _to = (_offset.add(_limit)).min(policyBooksArr.length()).max(_offset);

    _resultArr =  new WithdrawalRequestInfo[](_to - _offset);

    for (uint256 i = _offset; i < _to; i++) {
      IPolicyBook _currentPolicyBook = IPolicyBook(policyBooksArr.at(i));

      IPolicyBook.WithdrawalStatus _currentStatus = _currentPolicyBook.getWithdrawalStatus(_userAddr);

      if (_currentStatus == IPolicyBook.WithdrawalStatus.NONE ||
        _currentStatus == IPolicyBook.WithdrawalStatus.IN_QUEUE) {
        continue;
      }

      (uint256 _requestAmount, uint256 _readyToWithdrawDate) = _currentPolicyBook.withdrawalsInfo(_userAddr);
      uint256 _endWithdrawDate;

      if (block.timestamp > _readyToWithdrawDate) {
        _endWithdrawDate = _readyToWithdrawDate.add(_currentPolicyBook.READY_TO_WITHDRAW_PERIOD());
      }

      _resultArr[_arrLength] = WithdrawalRequestInfo(
        address(_currentPolicyBook),
        _requestAmount,
        _currentPolicyBook.convertDAIXtoDAI(_requestAmount),
        _currentPolicyBook.totalLiquidity().sub(_currentPolicyBook.totalCoverTokens()),
        _readyToWithdrawDate,
        _endWithdrawDate
      );

      _arrLength++;
    }
  }

  function getWithdrawalQueueInfos(address _userAddr, uint256 _offset, uint256 _limit)
    external
    view
    returns (uint256 _arrLength, WithdrawalQueueInfo[] memory _resultArr)
  {
    EnumerableSet.AddressSet storage policyBooksArr = _policyBooks[_userAddr];

    uint256 _to = (_offset.add(_limit)).min(policyBooksArr.length()).max(_offset);

    _resultArr =  new WithdrawalQueueInfo[](_to - _offset);

    for (uint256 i = _offset; i < _to; i++) {
      IPolicyBook _currentPolicyBook = IPolicyBook(policyBooksArr.at(i));

      if (_currentPolicyBook.getWithdrawalStatus(_userAddr) != IPolicyBook.WithdrawalStatus.IN_QUEUE) {
        continue;
      }

      (uint256 _requestAmount, ) = _currentPolicyBook.withdrawalsInfo(_userAddr);
      (bool _isExitPossible, uint256 _userIndex) = _currentPolicyBook.isExitFromQueuePossible(_userAddr);

      if (!_isExitPossible) {
        _userIndex = _currentPolicyBook.getIndexInQueue(_userAddr);
      }

      _resultArr[_arrLength] = WithdrawalQueueInfo(
        address(_currentPolicyBook),
        _requestAmount,
        _currentPolicyBook.convertDAIXtoDAI(_requestAmount),
        _isExitPossible,
        _userIndex
      );

      _arrLength++;
    }
  }
}
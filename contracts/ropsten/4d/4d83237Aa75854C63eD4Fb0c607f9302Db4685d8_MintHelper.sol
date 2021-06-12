//SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../governance/Controllable.sol";
import "./RewardToken.sol";

contract MintHelper is Controllable {
  using SafeMath for uint256;

  string public constant VERSION = "0";

  uint256 public baseRatio = 7000; // 70% always goes to rewards
  uint256 public fundsRatio = 3000; // 30% goes to different teams and the op fund
  uint256 public totalRatio = 10000;

  address public token;
  address public distributor;
  mapping(address => uint256) public operatingFunds;
  address[] public operatingFundsList;


  event FundsChanged(address[] funds, uint256[] fractions);
  event TokenSetup(address token);
  event DistributorChanged(address value);
  event AdminChanged(address newAdmin);

  constructor(
    address _controller,
    address _distributor,
    address[] memory _funds,
    uint256[] memory _fundsFractions
  ) {
    require(_distributor != address(0), "distributor is zero");
    Controllable.initializeControllable(_controller);
    distributor = _distributor;
    setOperatingFunds(_funds, _fundsFractions);
  }

  function mint(uint256 amount) public onlyGovernance {
    require(amount != 0, "Amount should be greater than 0");
    require(token != address(0), "Token not init");

    if (RewardToken(token).mintingStartTs() == 0) {
      RewardToken(token).startMinting();
    }

    // mint the base amount to distributor
    uint256 toDistributor = amount.mul(baseRatio).div(totalRatio);
    ERC20PresetMinterPauser(token).mint(distributor, toDistributor);

    uint256 sum = toDistributor;
    // mint to each fund
    for (uint256 i; i < operatingFundsList.length; i++) {
      address fund = operatingFundsList[i];
      uint256 toFund = amount.mul(operatingFunds[fund]).div(totalRatio);
      //a little trick to avoid rounding
      if (sum.add(toFund) > amount.sub(operatingFundsList.length).sub(1)
        && sum.add(toFund) < amount) {
        toFund = amount.sub(sum);
      }
      sum += toFund;
      ERC20PresetMinterPauser(token).mint(fund, toFund);
    }
    require(sum == amount, "wrong check sum");
  }

  function setToken(address _token) public onlyGovernance {
    require(_token != address(0), "Address should not be 0");
    require(token == address(0), "Only initial setup allowed");
    token = _token;
    emit TokenSetup(_token);
  }

  function setDistributor(address _distributor) public onlyGovernance {
    require(_distributor != address(0), "Address should not be 0");
    distributor = _distributor;
    emit DistributorChanged(_distributor);
  }

  function setOperatingFunds(address[] memory _funds, uint256[] memory _fractions) public onlyGovernance {
    require(_funds.length == _fractions.length, "wrong size");
    clearFunds();
    uint256 fractionSum;
    for (uint256 i; i < _funds.length; i++) {
      require(_funds[i] != address(0), "Address should not be 0");
      require(_fractions[i] != 0, "Ratio should not be 0");
      fractionSum += _fractions[i];
      operatingFunds[_funds[i]] = _fractions[i];
      operatingFundsList.push(_funds[i]);
    }
    require(fractionSum == fundsRatio, "wrong sum of fraction");
    emit FundsChanged(_funds, _fractions);
  }

  function clearFunds() private {
    for (uint256 i; i < operatingFundsList.length; i++) {
      delete operatingFunds[operatingFundsList[i]];
      delete operatingFundsList[i];
    }
  }

  function changeAdmin(address _newAdmin) public onlyGovernance {
    require(token != address(0), "Token not init");
    require(_newAdmin != address(0), "Address should not be 0");
    RewardToken(token).changeAdmin(_newAdmin);
    emit AdminChanged(_newAdmin);
  }
}
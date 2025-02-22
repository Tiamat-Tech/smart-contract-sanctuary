// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.5;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./LPFarm.sol";
import "./IRewardDistributionRecipientTokenOnly.sol";

contract FarmController is OwnableUpgradeable {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  IRewardDistributionRecipientTokenOnly[] public farms;
  
  mapping(address => address) public lpFarm;

  mapping(address => uint256) public rate;

  uint256 public weightSum;

  IERC20 public rewardToken;

  function initialize(address token)
  external
  {
    __Ownable_init();
    rewardToken = IERC20(token);
  }

  function addFarm(address _lptoken)
  external
  onlyOwner
  returns (address farm)
  {
    require(lpFarm[_lptoken] == address(0), "farm exist");
    bytes memory bytecode = type(LPFarm).creationCode;
    bytes32 salt = keccak256(abi.encodePacked(_lptoken));
    assembly {
      farm := create2(0, add(bytecode, 32), mload(bytecode), salt)
    }
    LPFarm(farm).initialize(_lptoken, address(this));
    farms.push(IRewardDistributionRecipientTokenOnly(farm));
    rewardToken.approve(farm, uint256(- 1));
    lpFarm[_lptoken] = farm;
    // it will just set the rates to zero before it get's it's own rate
  }

  function setRates(uint256[] memory _rates)
  external
  onlyOwner
  {
    require(_rates.length == farms.length);
    uint256 sum = 0;
    for (uint256 i = 0; i < _rates.length; i++) {
      sum += _rates[i];
      rate[address(farms[i])] = _rates[i];
    }
    weightSum = sum;
  }

  function setRateOf(address _farm, uint256 _rate)
  external
  onlyOwner
  {
    weightSum -= rate[_farm];
    weightSum += _rate;
    rate[_farm] = _rate;
  }

  function notifyRewards(uint256 amount)
  external
  onlyOwner
  {
    rewardToken.transferFrom(msg.sender, address(this), amount);
    for (uint256 i = 0; i < farms.length; i++) {
      IRewardDistributionRecipientTokenOnly farm = farms[i];
      farm.notifyRewardAmount(amount.mul(rate[address(farm)]).div(weightSum));
    }
  }

  // should transfer rewardToken prior to calling this contract
  // this is implemented to take care of the out-of-gas situation
  function notifyRewardsPartial(uint256 amount, uint256 from, uint256 to)
  external
  onlyOwner
  {
    require(from < to, "from should be smaller than to");
    require(to <= farms.length, "to should be smaller or equal to farms.length");
    for (uint256 i = from; i < to; i++) {
      IRewardDistributionRecipientTokenOnly farm = farms[i];
      farm.notifyRewardAmount(amount.mul(rate[address(farm)]).div(weightSum));
    }
  }

  function getFarmsCount() 
  external 
  view 
  returns (uint256) 
  {
    return farms.length;
  }

  function getFarm(uint _index)
  external
  view
  returns (IRewardDistributionRecipientTokenOnly)
  {
    return farms[_index];
  }
}
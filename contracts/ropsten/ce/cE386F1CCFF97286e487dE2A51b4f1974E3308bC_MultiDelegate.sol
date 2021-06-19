// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import { SafeMath } from "./SafeMath.sol";

interface IERC20 {
  function transfer(address recipient, uint256 amount) external returns (bool);
  function balanceOf(address owner) external view returns (uint256);
  function transferFrom(address _from, address to, uint _value) external returns (bool);
}


contract MultiDelegate {
  address[] public delegators;
  IERC20 private voteToken;
  mapping(address => mapping(address => uint256)) delegateAmount;
  mapping(address => uint256) delegatorAmount;

  constructor(address _voteToken) {
    voteToken = IERC20(_voteToken);
  }

  function delegate(address delegator, uint256 amount) public {
    uint256 i;
    bool _isin = false;
    for (i = 0; i < delegators.length; i++) {
      if(delegators[i] == delegator) {
        _isin = true;
        break;
      }
    }
    require(voteToken.balanceOf(msg.sender)>=amount, "Insuffient Funds!");
    uint256 curAmount = delegateAmount[msg.sender][delegator] > 0 ? delegateAmount[msg.sender][delegator]: 0;
    uint256 curDelegatorAmount = delegatorAmount[delegator] > 0 ? delegatorAmount[delegator] : 0;
    delegateAmount[msg.sender][delegator] += amount;
    delegatorAmount[delegator] += amount;
    voteToken.transferFrom(msg.sender, address(this), amount);
    emit delegateAdded(msg.sender, delegator, amount);
  }

  // Events
  event delegateAdded(address voter, address delegator, uint256 amount);

}
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import './interfaces/IKeep3rV1.sol';
import './interfaces/IKeep3rV1Proxy.sol';
import './peripherals/Keep3rGovernance.sol';

contract Keep3rV1Proxy is IKeep3rV1Proxy, Keep3rGovernance {
  address public override keep3rV1;
  address public override minter;

  constructor(address _governance, address _keep3rV1) Keep3rGovernance(_governance) {
    keep3rV1 = _keep3rV1;
  }

  function setKeep3rV1(address _keep3rV1) external override onlyGovernance noZeroAddress(_keep3rV1) {
    keep3rV1 = _keep3rV1;
  }

  function setMinter(address _minter) external override onlyGovernance noZeroAddress(_minter) {
    minter = _minter;
  }

  function mint(uint256 _amount) external override onlyMinter {
    _mint(msg.sender, _amount);
  }

  function mint(address _account, uint256 _amount) external override onlyGovernance {
    _mint(_account, _amount);
  }

  function setKeep3rV1Governance(address _governance) external override onlyGovernance {
    IKeep3rV1(keep3rV1).setGovernance(_governance);
  }

  function acceptKeep3rV1Governance() external override onlyGovernance {
    IKeep3rV1(keep3rV1).acceptGovernance();
  }

  function dispute(address _keeper) external override onlyGovernance {
    IKeep3rV1(keep3rV1).dispute(_keeper);
  }

  function slash(
    address _bonded,
    address _keeper,
    uint256 _amount
  ) external override onlyGovernance {
    IKeep3rV1(keep3rV1).slash(_bonded, _keeper, _amount);
  }

  function revoke(address _keeper) external override onlyGovernance {
    IKeep3rV1(keep3rV1).revoke(_keeper);
  }

  function resolve(address _keeper) external override onlyGovernance {
    IKeep3rV1(keep3rV1).resolve(_keeper);
  }

  function addJob(address _job) external override onlyGovernance {
    IKeep3rV1(keep3rV1).addJob(_job);
  }

  function removeJob(address _job) external override onlyGovernance {
    IKeep3rV1(keep3rV1).removeJob(_job);
  }

  function addKPRCredit(address _job, uint256 _amount) external override onlyGovernance {
    IKeep3rV1(keep3rV1).addKPRCredit(_job, _amount);
  }

  function approveLiquidity(address _liquidity) external override onlyGovernance {
    IKeep3rV1(keep3rV1).approveLiquidity(_liquidity);
  }

  function revokeLiquidity(address _liquidity) external override onlyGovernance {
    IKeep3rV1(keep3rV1).revokeLiquidity(_liquidity);
  }

  function setKeep3rHelper(address _keep3rHelper) external override onlyGovernance {
    IKeep3rV1(keep3rV1).setKeep3rHelper(_keep3rHelper);
  }

  function addVotes(address _voter, uint256 _amount) external override onlyGovernance {
    IKeep3rV1(keep3rV1).addVotes(_voter, _amount);
  }

  function removeVotes(address _voter, uint256 _amount) external override onlyGovernance {
    IKeep3rV1(keep3rV1).removeVotes(_voter, _amount);
  }

  modifier onlyMinter {
    if (msg.sender != minter) revert OnlyMinter();
    _;
  }

  modifier noZeroAddress(address _address) {
    if (_address == address(0)) revert ZeroAddress();
    _;
  }

  function _mint(address _account, uint256 _amount) internal {
    IKeep3rV1(keep3rV1).mint(_amount);
    IKeep3rV1(keep3rV1).transfer(_account, _amount);
  }
}
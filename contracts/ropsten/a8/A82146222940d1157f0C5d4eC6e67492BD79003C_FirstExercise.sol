//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@lbertenasco/contract-utils/contracts/utils/Governable.sol';
import '@lbertenasco/contract-utils/contracts/utils/Manageable.sol';
import '@lbertenasco/contract-utils/contracts/utils/CollectableDust.sol';

contract FirstExercise is ERC1155, Governable, Manageable, CollectableDust {

  constructor(
    string memory uri_,
    address _governor,
    address _manager
  ) ERC1155(uri_) Governable(_governor) Manageable(_manager) CollectableDust() {
    console.log('Deploying the First Excercise');
  }

  function sendDust(address _to, address _token, uint256 _amount) external override {
    console.log('We are using this function');
  }

  function setPendingGovernor(address _pendingGovernor) external override onlyGovernor {
    _setPendingGovernor(_pendingGovernor);
  }

  function acceptGovernor() external override onlyGovernor {
    _acceptGovernor();
  }

  function setPendingManager(address _pendingManager) external override onlyManager {
    _setPendingManager(_pendingManager);
  }

  function acceptManager() external override onlyManager {
    _acceptManager();
  }

  function mint(
    address _account,
    uint256 _id,
    uint256 _amount,
    bytes memory _data
  ) external onlyGovernor {
    _mint(_account, _id, _amount, _data);
  }

  function burn(
    address _account,
    uint256 _id,
    uint256 _amount
  ) external onlyManager {
    _burn(_account, _id, _amount);
  }
}
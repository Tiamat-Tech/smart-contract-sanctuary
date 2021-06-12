//SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../upgradability/BaseUpgradeabilityProxy.sol";
import "../interface/IBookkeeper.sol";


contract BookkeeperProxy is BaseUpgradeabilityProxy {

  constructor(address _implementation) {
    _setImplementation(_implementation);
  }

  function upgrade(address _newImplementation) external {
    require(IBookkeeper(address(this)).isGovernance(msg.sender), "forbidden");
    _upgradeTo(_newImplementation);
  }

  function implementation() external view returns (address) {
    return _implementation();
  }
}
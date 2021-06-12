//SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;

import "@openzeppelin/contracts/proxy/UpgradeableProxy.sol";
import "../interface/IBookkeeper.sol";


contract BookkeeperProxy is UpgradeableProxy {

  constructor(address _logic) UpgradeableProxy(_logic, "") {
    _upgradeTo(_logic);
  }

  function upgrade(address _newImplementation) external {
    require(IBookkeeper(address(this)).isGovernance(msg.sender), "forbidden");
    _upgradeTo(_newImplementation);
  }

  function implementation() external view returns (address) {
    return _implementation();
  }
}
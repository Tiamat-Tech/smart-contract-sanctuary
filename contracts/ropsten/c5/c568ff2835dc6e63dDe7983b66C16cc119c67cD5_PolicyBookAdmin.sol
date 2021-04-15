// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IPolicyBookAdmin.sol";
import "./interfaces/IPolicyBookRegistry.sol";
import "./interfaces/IContractsRegistry.sol";
import "./interfaces/IPolicyBook.sol";

import "./abstract/AbstractDependant.sol";

import "./helpers/Upgrader.sol";

contract PolicyBookAdmin is IPolicyBookAdmin, OwnableUpgradeable, AbstractDependant {
  using Math for uint256;
  using SafeMath for uint256;

  IContractsRegistry public contractsRegistry;
  IPolicyBookRegistry public policyBookRegistry;
  
  Upgrader internal upgrader;

  function __PolicyBookAdmin_init() external initializer {
    __Ownable_init();

    upgrader = new Upgrader();
  }

  function setDependencies(IContractsRegistry _contractsRegistry) external override onlyInjectorOrZero { 
    contractsRegistry = _contractsRegistry;

    policyBookRegistry = IPolicyBookRegistry(_contractsRegistry.getPolicyBookRegistryContract());   
  }

  function injectDependenciesToExistingPolicies(uint256 offset, uint256 limit) external onlyOwner {
    address[] memory _policies = policyBookRegistry.list(offset, limit);
    IContractsRegistry _contractsRegistry = contractsRegistry;

    uint256 to = (offset.add(limit)).min(_policies.length).max(offset);

    for (uint256 i = offset; i < to; i++) {
      AbstractDependant dependant = AbstractDependant(_policies[i]);

      if (dependant.injector() == address(0)) {
        dependant.setInjector(address(this));
      }

      dependant.setDependencies(_contractsRegistry);
    }
  }

  function getUpgrader() external view override returns (address) {
    require (address(upgrader) != address(0), "PolicyBookAdmin: Bad upgrader");

    return address(upgrader);
  }

  function getImplementation(address policyBookAddress) external returns (address) {
    require(policyBookRegistry.isPolicyBook(policyBookAddress), "PolicyBookAdmin: Not a policybook");

    return upgrader.getImplementation(policyBookAddress);
  }

  /// @notice set whitelisted to true is you want to whitelist or false to blacklist
  function whitelist(address policyBookAddress, bool whitelisted) external onlyOwner {
    IPolicyBook(policyBookAddress).whitelist(whitelisted);
  }

  function upgradeExistingPolicies(uint256 offset, uint256 limit) external onlyOwner {
    address[] memory _policies = policyBookRegistry.list(offset, limit);
    address policyBookImpl = contractsRegistry.getPolicyBookImplementation();

    uint256 to = (offset.add(limit)).min(_policies.length).max(offset);
    
    for (uint256 i = offset; i < to; i++) {
      upgrader.upgrade(_policies[i], policyBookImpl);
    }
  }
}
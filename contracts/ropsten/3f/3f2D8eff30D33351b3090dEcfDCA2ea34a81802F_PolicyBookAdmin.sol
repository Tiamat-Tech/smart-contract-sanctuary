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
    address private policyBookImplementationAddress;

    event PolicyBookWhitelisted(address policyBookAddress, bool trigger);

    function __PolicyBookAdmin_init(address _policyBookImplementationAddress)
        external
        initializer
    {
        __Ownable_init();

        upgrader = new Upgrader();

        policyBookImplementationAddress = _policyBookImplementationAddress;
    }

    function setDependencies(IContractsRegistry _contractsRegistry)
        external
        override
        onlyInjectorOrZero
    {
        contractsRegistry = _contractsRegistry;

        policyBookRegistry = IPolicyBookRegistry(
            _contractsRegistry.getPolicyBookRegistryContract()
        );
    }

    function injectDependenciesToExistingPolicies(uint256 offset, uint256 limit)
        external
        onlyOwner
    {
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
        require(address(upgrader) != address(0), "PolicyBookAdmin: Bad upgrader");

        return address(upgrader);
    }

    function getImplementationOfPolicyBook(address policyBookAddress)
        external
        override
        returns (address)
    {
        require(
            policyBookRegistry.isPolicyBook(policyBookAddress),
            "PolicyBookAdmin: Not a policybook"
        );

        return upgrader.getImplementation(policyBookAddress);
    }

    function getCurrentPolicyBooksImplementation() external view override returns (address) {
        return policyBookImplementationAddress;
    }

    /// @notice set whitelisted to true is you want to whitelist or false to blacklist
    function whitelist(address policyBookAddress, bool whitelisted) external onlyOwner {
        IPolicyBook(policyBookAddress).whitelist(whitelisted);

        emit PolicyBookWhitelisted(policyBookAddress, whitelisted);
    }

    function upgradePolicyBooks(
        address policyBookImpl,
        uint256 offset,
        uint256 limit
    ) external onlyOwner {
        _setPolicyBookImplementation(policyBookImpl);

        address[] memory _policies = policyBookRegistry.list(offset, limit);

        uint256 to = (offset.add(limit)).min(_policies.length).max(offset);

        for (uint256 i = offset; i < to; i++) {
            upgrader.upgrade(_policies[i], policyBookImpl);
        }
    }

    function _setPolicyBookImplementation(address policyBookImpl) internal {
        if (policyBookImplementationAddress != policyBookImpl) {
            policyBookImplementationAddress = policyBookImpl;
        }
    }
}
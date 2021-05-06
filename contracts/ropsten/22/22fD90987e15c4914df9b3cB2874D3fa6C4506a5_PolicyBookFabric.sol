// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

import "./interfaces/IPolicyBook.sol";
import "./interfaces/IPolicyBookAdmin.sol";
import "./interfaces/IPolicyBookFabric.sol";
import "./interfaces/IPolicyBookRegistry.sol";
import "./interfaces/IContractsRegistry.sol";

import "./abstract/AbstractDependant.sol";

contract PolicyBookFabric is IPolicyBookFabric, AbstractDependant {
    IContractsRegistry public contractsRegistry;
    IPolicyBookRegistry public policyBookRegistry;
    IPolicyBookAdmin public policyBookAdmin;

    event Created(address insured, ContractType contractType, address at);

    function setDependencies(IContractsRegistry _contractsRegistry)
        external
        override
        onlyInjectorOrZero
    {
        contractsRegistry = _contractsRegistry;

        policyBookRegistry = IPolicyBookRegistry(
            _contractsRegistry.getPolicyBookRegistryContract()
        );
        policyBookAdmin = IPolicyBookAdmin(contractsRegistry.getPolicyBookAdminContract());
    }

    function create(
        address _insuranceContract,
        ContractType _contractType,
        string calldata _description,
        string calldata _projectSymbol
    ) external override returns (address) {
        TransparentUpgradeableProxy _proxy =
            new TransparentUpgradeableProxy(
                policyBookAdmin.getCurrentPolicyBooksImplementation(),
                policyBookAdmin.getUpgrader(),
                ""
            );

        IPolicyBook(address(_proxy)).__PolicyBook_init(
            _insuranceContract,
            _contractType,
            _description,
            _projectSymbol
        );

        AbstractDependant(address(_proxy)).setDependencies(contractsRegistry);
        AbstractDependant(address(_proxy)).setInjector(address(policyBookAdmin));

        policyBookRegistry.add(_insuranceContract, address(_proxy));

        emit Created(_insuranceContract, _contractType, address(_proxy));

        return address(_proxy);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

import "./interfaces/IContractsRegistry.sol";

contract ContractsRegistry is IContractsRegistry, Ownable, AccessControl {
    mapping (bytes32 => address) private _contracts;
    mapping (address => bool) private _isProxy;

    bytes32 constant public REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");
    
    bytes32 constant public UNISWAP_BMI_TO_ETH_PAIR_NAME = keccak256("UNI_BMI_ETH_PAIR");    

    bytes32 constant public BMI_STAKING_NAME = keccak256("BMI_STAKING_NAME");
    
    bytes32 constant public BMI_NAME = keccak256("BMI");    
    bytes32 constant public STKBMI_NAME = keccak256("STK_BMI");    

    bytes32 constant public LIQUIDITY_MINING_STAKING_NAME = keccak256("LIQ_MINING_STAKING");

    modifier onlyAdmin() {
        require(hasRole(REGISTRY_ADMIN_ROLE, msg.sender), "ContractsRegistry: Caller is not an admin");
        _;
    }

    constructor() {
        _setupRole(REGISTRY_ADMIN_ROLE, owner());        
        _setRoleAdmin(REGISTRY_ADMIN_ROLE, REGISTRY_ADMIN_ROLE);
    }        

    function getUniswapBMIToETHPairContract() external view override returns (address) {
        return getContract(UNISWAP_BMI_TO_ETH_PAIR_NAME);
    }

    function getBMIContract() external view override returns (address) {
        return getContract(BMI_NAME);
    }

    function getBMIStakingContract() external view override returns (address) {
        return getContract(BMI_STAKING_NAME);
    }

    function getSTKBMIContract() external view override returns (address) {
        return getContract(STKBMI_NAME);
    }

    function getLiquidityMiningStakingContract() external override view returns (address) {
        return getContract(LIQUIDITY_MINING_STAKING_NAME);
    }    

    function getContract(bytes32 name) public view returns (address) {
        require(_contracts[name] != address(0), "ContractsRegistry: This mapping doesn't exist");

        return _contracts[name];
    }

    function upgradeContract(bytes32 name, address newImplementation) external onlyAdmin {
        require(_contracts[name] != address(0), "ContractsRegistry: This mapping doesn't exist");

        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(_contracts[name]));

        require(_isProxy[address(proxy)], "ContractsRegistry: Can't upgrade not a proxy contract");

        proxy.upgradeTo(newImplementation);
    }

    function addContract(bytes32 name, address contractAddress) external onlyAdmin {
        require(contractAddress != address(0), "ContractsRegistry: Null address is forbidden");        

        _contracts[name] = contractAddress;
    }

    function addProxyContract(bytes32 name, address contractAddress) external onlyAdmin {
        require(contractAddress != address(0), "ContractsRegistry: Null address is forbidden");        

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            contractAddress, address(this), ""
        );

        _contracts[name] = address(proxy);
        _isProxy[address(proxy)] = true;
    }

    function deleteContract(bytes32 name) external onlyAdmin {
        require(_contracts[name] != address(0), "ContractsRegistry: This mapping doesn't exist");

        delete _isProxy[_contracts[name]];
        delete _contracts[name];
    }
}
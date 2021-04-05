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

    bytes32 constant public POLICY_BOOK_IMPLEMENTATION_NAME = keccak256("BOOK_IMPLEMENTATION");    

    bytes32 constant public UNISWAP_ROUTER_NAME = keccak256("UNI_ROUTER");    
    bytes32 constant public UNISWAP_BMI_TO_ETH_PAIR_NAME = keccak256("UNI_BMI_ETH_PAIR");    

    bytes32 constant public PRICE_FEED_NAME = keccak256("PRICE_FEED");

    bytes32 constant public POLICY_BOOK_REGISTRY_NAME = keccak256("BOOK_REGISTRY");
    bytes32 constant public POLICY_BOOK_FABRIC_NAME = keccak256("FABRIC");
    bytes32 constant public POLICY_BOOK_VOTING_NAME = keccak256("POLICY_BOOK_VOTING");
    bytes32 constant public POLICY_BOOK_ADMIN_NAME = keccak256("POLICY_BOOK_ADMIN");

    bytes32 constant public BMI_STAKING_NAME = keccak256("BMI_STAKING_NAME");
    bytes32 constant public BMI_DAI_STAKING_NAME = keccak256("STAKING");
    bytes32 constant public YIELD_GENERATOR_NAME = keccak256("YIELD_GENERATOR");

    bytes32 constant public WETH_NAME = keccak256("WETH");
    bytes32 constant public DAI_NAME = keccak256("DAI");
    bytes32 constant public BMI_NAME = keccak256("BMI");    
    bytes32 constant public STKBMI_NAME = keccak256("STK_BMI");    
    bytes32 constant public VBMI_NAME= keccak256("VBMI");

    bytes32 constant public LIQUIDITY_MINING_NFT_NAME = keccak256("LIQ_MINING_NFT");
    bytes32 constant public LIQUIDITY_MINING_NAME = keccak256("LIQ_MINING");
    bytes32 constant public LIQUIDITY_MINING_STAKING_NAME = keccak256("LIQ_MINING_STAKING");

    bytes32 constant public POLICY_REGISTRY_NAME = keccak256("POLICY_REGISTRY");
    bytes32 constant public POLICY_QUOTE_NAME = keccak256("POLICY_QUOTE");

    bytes32 constant public CLAIMING_REGISTRY_NAME = keccak256("CLAIMING_REGISTRY");    
    bytes32 constant public CLAIM_VOTING_NAME = keccak256("CLAIM_VOTING");
    bytes32 constant public REPUTATION_SYSTEM_NAME = keccak256("REPUTATION_SYSTEM");
    bytes32 constant public REINSURANCE_POOL_NAME = keccak256("REINSURANCE_POOL");

    modifier onlyAdmin() {
        require(hasRole(REGISTRY_ADMIN_ROLE, msg.sender), "ContractsRegistry: Caller is not an admin");
        _;
    }

    constructor() {
        _setupRole(REGISTRY_ADMIN_ROLE, owner());        
        _setRoleAdmin(REGISTRY_ADMIN_ROLE, REGISTRY_ADMIN_ROLE);
    }    

    function getUniswapRouterContract() external view override returns (address) {
        return getContract(UNISWAP_ROUTER_NAME);
    }

    function getUniswapBMIToETHPairContract() external view override returns (address) {
        return getContract(UNISWAP_BMI_TO_ETH_PAIR_NAME);
    }

    function getWETHContract() external view override returns (address) {
        return getContract(WETH_NAME);
    }

    function getDAIContract() external view override returns (address) {
        return getContract(DAI_NAME);
    }

    function getBMIContract() external view override returns (address) {
        return getContract(BMI_NAME);
    }

    function getPriceFeedContract() external view override returns (address) {
        return getContract(PRICE_FEED_NAME);
    }

    function getPolicyBookRegistryContract() external view override returns (address) {
        return getContract(POLICY_BOOK_REGISTRY_NAME);
    }

    function getPolicyBookFabricContract() external view override returns (address) {
        return getContract(POLICY_BOOK_FABRIC_NAME);
    }

    function getBMIDAIStakingContract() external view override returns (address) {
        return getContract(BMI_DAI_STAKING_NAME);
    }

    function getYieldGeneratorContract() external view override returns (address) {
        return getContract(YIELD_GENERATOR_NAME);
    }

    function getLiquidityMiningNFTContract() external view override returns (address) {
        return getContract(LIQUIDITY_MINING_NFT_NAME);
    }

    function getLiquidityMiningContract() external view override returns (address) {
        return getContract(LIQUIDITY_MINING_NAME);
    }

    function getClaimingRegistryContract() external view override returns (address) {
        return getContract(CLAIMING_REGISTRY_NAME);
    }

    function getPolicyRegistryContract() external view override returns (address) {
        return getContract(POLICY_REGISTRY_NAME);
    }

    function getClaimVotingContract() external view override returns (address) {
        return getContract(CLAIM_VOTING_NAME);
    }

    function getReputationSystemContract() external view override returns (address) {
        return getContract(REPUTATION_SYSTEM_NAME);
    }

    function getReinsurancePoolContract() external view override returns (address) {
        return getContract(REINSURANCE_POOL_NAME);
    }

    function getPolicyBookVotingContract() external view override returns (address) {
        return getContract(POLICY_BOOK_VOTING_NAME);
    }

    function getPolicyBookImplementation() external view override returns (address) {
        return getContract(POLICY_BOOK_IMPLEMENTATION_NAME);
    }

    function getPolicyBookAdminContract() external view override returns (address) {
        return getContract(POLICY_BOOK_ADMIN_NAME);
    }

    function getPolicyQuoteContract() external view override returns (address) {
        return getContract(POLICY_QUOTE_NAME);
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

    function getVBMIContract() external view override returns (address) {
        return getContract(VBMI_NAME);
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
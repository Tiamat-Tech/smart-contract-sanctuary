// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./interface/IAssetManagerFactory.sol";
import "./interface/IStrategyFactory.sol";
import "./interface/IAssetManager.sol";
import "./interface/IStrategy.sol";
import "./interface/IAdamOwned.sol";
import "./interface/IManageable.sol";
import "hardhat/console.sol";

contract Adam {
    IAssetManagerFactory public assetManagerFactory;
    IStrategyFactory public strategyFactory;

    address[] public assetManagers;
    address[] private _strategies;
    address[] public publicStrategies;

    mapping(address => bool) public assetManagerRegistry;
    mapping(address => bool) public strategyRegistry;

    event CreateAssetManager(address assetManager, bytes32 name, address creator);
    event CreateStrategy(address assetManager, address strategy, bytes32 name, address creator, bool isPrivate);

    constructor (address _assetManagerFactory, address _strategyFactory) {
        assetManagerFactory = IAssetManagerFactory(_assetManagerFactory);
        strategyFactory = IStrategyFactory(_strategyFactory);
        IAdamOwned(_assetManagerFactory).setAdam(address(this));
        IAdamOwned(_strategyFactory).setAdam(address(this));
    }
    
    function countAssetManagers() public view returns (uint256) {
        return assetManagers.length;
    }
    function countStrategies() public view returns (uint256) {
        return _strategies.length;
    }
    function countPublicStrategies() public view returns (uint256) {
        return publicStrategies.length;
    }

    function createAssetManager(bytes32 _name) public returns (address) {
        address _am = assetManagerFactory.create(msg.sender, _name);
        assetManagers.push(_am);
        assetManagerRegistry[_am] = true;
        emit CreateAssetManager(_am, _name, msg.sender);
        return _am;
    }

    function createStrategy(address _assetManager, bytes32 _name, bool _private) public returns (address) {
        require(assetManagerRegistry[_assetManager], "not assetManager");
        require(IManageable(_assetManager).isOwner(msg.sender), "access denied");

        address _s = strategyFactory.create(_assetManager, _name);
        _strategies.push(_s);
        strategyRegistry[_s] = true;
        if (!_private) {
            publicStrategies.push(_s);
        }
        emit CreateStrategy(_assetManager, _s, _name, msg.sender, _private);
        return _s;
    }
}
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Registry is Ownable {
    // Map asset addresses to indexes.
    mapping(address => uint32) public assetAddressToIndex;
    mapping(uint32 => address) public assetIndexToAddress;
    uint32 numAssets = 0;

    // Valid strategies.
    mapping(address => uint32) public strategyAddressToIndex;
    mapping(uint32 => address) public strategyIndexToAddress;
    uint32 numStrategies = 0;

    event AssetRegistered(address asset, uint32 assetId);
    event StrategyRegistered(address strategy, uint32 strategyId);

    /**
     * @notice Register a asset
     * @param _asset The asset token address;
     */
    function registerAsset(address _asset) external onlyOwner {
        require(assetAddressToIndex[_asset] == 0, "Asset already registered");

        // Register asset with an index >= 1 (zero is reserved).
        numAssets++;
        assetAddressToIndex[_asset] = numAssets;
        assetIndexToAddress[numAssets] = _asset;

        emit AssetRegistered(_asset, numAssets);
    }

    /**
     * @notice Register a strategy
     * @param _strategy The strategy contract address;
     */
    function registerStrategy(address _strategy) external onlyOwner {
        require(strategyAddressToIndex[_strategy] == 0, "Strategy already registered");

        // Register strategy with an index >= 1 (zero is reserved).
        numStrategies++;
        strategyAddressToIndex[_strategy] = numStrategies;
        strategyIndexToAddress[numStrategies] = _strategy;

        emit StrategyRegistered(_strategy, numStrategies);
    }
}
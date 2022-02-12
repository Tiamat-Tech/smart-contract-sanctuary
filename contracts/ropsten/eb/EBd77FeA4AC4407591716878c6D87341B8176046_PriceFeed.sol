// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DateTimeLibrary.sol";

interface IPriceOracleGetter {
  function getAssetPrice(address asset) external view returns (uint256);
}

interface IChainlinkAggregator {
  function latestAnswer() external view returns (int256);
}

contract PriceFeed is Pausable, Ownable {
    using DateTimeLibrary for uint256;

    struct Price {
        uint64 blockNumber;
        uint64 blockTimestamp;
        uint128 price;
    }

    mapping(address => Price) private _prices;
    mapping(address => IChainlinkAggregator) private assetsSources;

    event AssetSourceUpdated(address indexed asset, address indexed source);
    event FallbackOracleUpdated(address indexed fallbackOracle);
    event PricesSubmitted(address sybil, address assets, uint128 prices);

    constructor() {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /// @notice External function called by the Aave governance to set or replace sources of assets
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    function setAssetSources(address[] calldata assets, address[] calldata sources)
        external
        onlyOwner
    {
        _setAssetsSources(assets, sources);
    }

    /// @notice Internal function to set the sources for each asset
    /// @param assets The addresses of the assets
    /// @param sources The address of the source of each asset
    function _setAssetsSources(address[] memory assets, address[] memory sources) internal {
        require(assets.length == sources.length, 'INCONSISTENT_PARAMS_LENGTH');
        for (uint256 i = 0; i < assets.length; i++) {
        assetsSources[assets[i]] = IChainlinkAggregator(sources[i]);
        emit AssetSourceUpdated(assets[i], sources[i]);
        }
    }

    /// @notice Gets an asset price by address
    /// @param asset The asset address
    function getAssetPrice(address asset) public view returns (uint256) {
        IChainlinkAggregator source = assetsSources[asset];

        if (address(source) == address(0)) {
            return uint256(_prices[asset].price);
        } else {
            int256 price = IChainlinkAggregator(source).latestAnswer();
            if (price > 0) {
                return uint256(price);
            } else {
                return uint256(_prices[asset].price);
            }
        }
    }

    /// @notice Gets a list of prices from a list of assets addresses
    /// @param assets The list of assets addresses
    function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
        prices[i] = getAssetPrice(assets[i]);
        }
        return prices;
    }

    /// @notice Gets the address of the source for an asset address
    /// @param asset The address of the asset
    /// @return address The address of the source
    function getSourceOfAsset(address asset) external view returns (address) {
        return address(assetsSources[asset]);
    }

    function submitPrices(address assets, uint128 prices) external {
        _prices[assets] = Price(uint64(block.number), uint64(block.timestamp), prices);

        emit PricesSubmitted(msg.sender, assets, prices);
    }

    function getPricesData(address[] calldata assets) external view returns (Price[] memory) {
        Price[] memory result = new Price[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
        result[i] = _prices[assets[i]];
        }
        return result;
    }

}
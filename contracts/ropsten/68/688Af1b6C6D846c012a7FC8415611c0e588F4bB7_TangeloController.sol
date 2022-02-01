// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Market.sol";
import "./TNFT.sol";

contract TangeloController is Ownable {
    /**
     * @notice store of officially supported NFT collections
     */
    address[] private supportedCollections;

    /**
     * @notice mapping of NFT collection address to cooresponding market contract
     */
    mapping(address => address payable) private nftCollectionToMarket;

    /**
     * @notice admin function to add a new supported NFT collection and supported market
     * @param collectionAddress NFT Collection Address
     * @param newMarketAddress Cooresponding market contract
     */
    function _addSupportedMarkets(
        address collectionAddress,
        address payable newMarketAddress
    ) external onlyOwner {
        supportedCollections.push(newMarketAddress);
        nftCollectionToMarket[collectionAddress] = newMarketAddress;
    }

    /**
     * @notice Getter function for supportedCollections
     * @return list of official supported NFT collections
     */
    function getSupportedMarkets() external view returns (address[] memory) {
        return supportedCollections;
    }

    /**
     * @notice Returns market address given an NFT Collection Address
     * @param nftCollectionAddress NFT Collection Address
     * @return Market contract address
     */
    function getMarketForCollectionAddress(address nftCollectionAddress)
        public
        view
        returns (address payable)
    {
        return nftCollectionToMarket[nftCollectionAddress];
    }

    /**
     * @notice Returns total protocol assets across all markets
     * @return Total protocol assets
     */
    function getProtocolAssets() external view returns (uint256) {
        uint256 cash = 0;
        for (uint256 i = 0; i < supportedCollections.length; i++) {
            address collectionAddress = supportedCollections[i];
            address payable marketAddress = getMarketForCollectionAddress(
                collectionAddress
            );
            Market m = Market(marketAddress);
            cash += m.getAssets();
        }
        return cash;
    }
}
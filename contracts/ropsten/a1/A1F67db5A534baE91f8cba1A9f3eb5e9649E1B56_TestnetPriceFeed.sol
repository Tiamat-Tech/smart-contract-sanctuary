// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPriceFeed.sol";

/**
 * @title TestnetPriceFeed
 * @dev Store retrieve prices of different assets using a string -> int mapping
 */
contract TestnetPriceFeed is Ownable, IPriceFeed {
  struct PriceFeedItem {
    uint256 time;
    int256 price;
  }

  mapping(string => PriceFeedItem[]) public priceFeedItems;

  function store(string calldata _token, int256 _price) public {
    PriceFeedItem memory newPriceFeedItem;

    newPriceFeedItem.time = block.timestamp;
    newPriceFeedItem.price = _price;

    priceFeedItems[_token].push(newPriceFeedItem);
  }

  function getHistoricalPrice(string calldata _token, uint256 queryTimestamp)
    public
    view
    returns (int256)
  {
    require(priceFeedItems[_token].length > 0, "no priceFeedItems for _token");

    uint256 searchIndex = priceFeedItems[_token].length - 1;
    while (priceFeedItems[_token][searchIndex].time > queryTimestamp) {
      searchIndex -= 1;
    }

    return priceFeedItems[_token][searchIndex].price;
  }

  function getPrice(string calldata _token) public view returns (int256) {
    require(priceFeedItems[_token].length > 0, "no priceFeedItems for _token");

    uint256 lastIndex = priceFeedItems[_token].length - 1;
    return priceFeedItems[_token][lastIndex].price;
  }
}
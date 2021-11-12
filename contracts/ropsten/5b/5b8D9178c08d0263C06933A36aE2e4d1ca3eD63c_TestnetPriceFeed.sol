// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPriceFeed.sol";

contract TestnetPriceFeed is Ownable, IPriceFeed {
  mapping(string => mapping(uint256 => uint256)) public price;
  mapping(string => bool) public tokens;
  string[] public tokensList;

  function addToken(string calldata _token) external onlyOwner {
    tokens[_token] = true;
    tokensList.push(_token);
  }

  function clearTokens() external onlyOwner {
    for (uint256 i = 0; i < tokensList.length; i++) {
      delete tokens[tokensList[i]];
    }
    delete tokensList;
  }

  function store(
    uint256 _timestamp,
    string[] calldata _tokens,
    uint256[] calldata _prices
  ) external onlyOwner {
    require(_tokens.length == _prices.length, "uneven arrays");

    uint256 nearestMinuteTimestamp = _timestamp - (_timestamp % 60);

    for (uint256 i = 0; i < _tokens.length; i++) {
      require(tokens[_tokens[i]] == true, "invalid token");
      price[_tokens[i]][nearestMinuteTimestamp] = _prices[i];
    }
  }

  function getHistoricalPrice(string calldata _token, uint256 _timestamp)
    public
    view
    returns (uint256)
  {
    require(tokens[_token] == true, "invalid token");

    uint256 nearestMinuteTimestamp = _timestamp - (_timestamp % 60);
    uint256 queryLimit = _timestamp - 3600;
    uint256 result = 0;
    while (nearestMinuteTimestamp > queryLimit) {
      uint256 currentPrice = price[_token][nearestMinuteTimestamp];
      if (currentPrice > 0) {
        result = currentPrice;
        break;
      }
      nearestMinuteTimestamp -= 60;
    }
    return result;
  }

  function getPrice(string calldata _token) public view returns (uint256) {
    return getHistoricalPrice(_token, block.timestamp);
  }
}
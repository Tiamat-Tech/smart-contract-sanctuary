// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./IPriceFeed.sol";

contract PriceFeed is Ownable, IPriceFeed {
  mapping(string => address) public oracles;

  function addToken(string calldata _token, address _oracle) public onlyOwner {
    oracles[_token] = _oracle;
  }

  function getPrice(string calldata _token) public view returns (int256) {
    require(oracles[_token] != address(0), "invalid token");
    AggregatorV3Interface priceFeed = AggregatorV3Interface(oracles[_token]);
    (, int256 answer, , , ) = priceFeed.latestRoundData();
    return answer;
  }

  function getHistoricalPrice(string calldata _token, uint256)
    public
    view
    returns (int256)
  {
    // TODO: FIX THIS to acutally get the Historical Price
    return getPrice(_token);
  }
}
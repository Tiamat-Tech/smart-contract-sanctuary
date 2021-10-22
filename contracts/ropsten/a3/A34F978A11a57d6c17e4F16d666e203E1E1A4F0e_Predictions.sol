// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Predictions {
//  mapping (address => uint) balances;
//
//  event Transfer(address indexed _from, address indexed _to, uint256 _value);
//  event Faucet(address indexed _to, uint256 _value);
//
//  constructor() public {
//    balances[tx.origin] = 10000;
//  }
//
//  function sendTokens(address receiver, uint amount) public returns(bool sufficient) {
//    if (balances[msg.sender] < amount) return false;
//    balances[msg.sender] -= amount;
//    balances[receiver] += amount;
//    emit Transfer(msg.sender, receiver, amount);
//    return true;
//  }
//
//  function faucet(uint amount) public returns(bool sufficient) {
//    balances[msg.sender] += amount;
//    emit Faucet(msg.sender, amount);
//    return true;
//  }
//
//  function getBalance(address addr) public view returns(uint) {
//    return balances[addr];
//  }

  //int256 constant NULL_PRICE = -1;

  struct Prediction {
    address creator;
    uint256 price;
    uint256 deadline;
    string dataFeedAddress;
  }

  Prediction[] public predictions;
  AggregatorV3Interface internal priceFeed;

  constructor() {
    priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
  }

  /**
   * Returns the latest price
   */
  function getLatestPrice() public view returns (int) {
    (
    uint80 roundID,
    int price,
    uint startedAt,
    uint timeStamp,
    uint80 answeredInRound
    ) = priceFeed.latestRoundData();
    return price;
  }

  //
  function createPredictionForMinPrice(uint256 _price, uint256 _deadline, string memory _dataFeedAddress) public {
    // require price >= 0

    createPrediction(msg.sender, _price, _deadline, _dataFeedAddress);
  }

  //
  function createPrediction(address _creator, uint256 _price, uint256 _deadline, string memory _dataFeedAddress) internal {
    // require price >= 0

    // key value mapping
    predictions.push(Prediction({
      creator: _creator,
      deadline: _deadline,
      dataFeedAddress: _dataFeedAddress,
      price: _price
    }));

    // initialize an empty struct and then update it
//    Todo memory todo;
//    todo.text = _text;
//    // todo.completed initialized to false
//    predictions.push(todo);
  }
}
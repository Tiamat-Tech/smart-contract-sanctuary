//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';

contract CryptoRoll {
  using SafeMath for uint256;

  event CreatedStream(
    uint256 id,
    address source,
    address destination,
    address token,
    uint256 amount,
    uint256 startTime,
    uint256 endTime
  );

  event WithdrawnFromStream(uint256 id, address destination, uint256 amount);

  event CancelledStream(
    uint256 id,
    address source,
    address destination,
    uint256 sourceBalance,
    uint256 destinationBalance
  );

  struct Stream {
    uint256 id;
    address source;
    address destination;
    address token;
    uint256 initialBalance;
    uint256 currentBalance;
    uint256 startTime;
    uint256 endTime;
    // TODO: More fields for contract terms, e.g.
    // milestones, insurance, yield farming, etc.
  }

  uint256 public nextAvailableStreamId = 1;

  // A mapping from Stream id to Stream details
  mapping(uint256 => Stream) public streamIdToStream;

  // A mapping from user ids to associated Stream ids.
  // Specifically, for a given user `u`, userIdToStreamIds[u]
  // stores the ids of all Streams for which `u` is
  // either the payer or the payee
  mapping(address => uint256[]) public userIdToStreamIds;

  constructor() {
    console.log('Deploying contract');
  }

  function createStream(
    address _destination,
    address _token,
    uint256 _amount,
    uint256 _startTime,
    uint256 _endTime
  ) public returns (uint256) {
    // Validate parameters
    require(_destination != address(0), 'Destination cannot be null');
    require(_destination != msg.sender, 'Destination cannot be source');
    require(_destination != address(this), 'Destination cannot be contract');
    require(_startTime >= block.timestamp, 'Start must be after block');
    require(_startTime < _endTime, 'Start must be before end');
    require(_amount > 0, 'Amount must be positive');
    require(_token != address(0), 'Token cannot be null');

    // Lock up funds in contract
    IERC20(_token).approve(address(this), _amount);
    IERC20(_token).transferFrom(msg.sender, address(this), _amount);

    // Create and store Stream
    uint256 streamId = nextAvailableStreamId;
    streamIdToStream[streamId] = Stream({
      id: streamId,
      source: msg.sender,
      destination: _destination,
      token: _token,
      initialBalance: _amount,
      currentBalance: _amount,
      startTime: _startTime,
      endTime: _endTime
    });

    // Update other storage variables
    userIdToStreamIds[msg.sender].push(streamId);
    userIdToStreamIds[_destination].push(streamId);
    nextAvailableStreamId = nextAvailableStreamId.add(1);

    emit CreatedStream(
      streamId,
      msg.sender,
      _destination,
      _token,
      _amount,
      _startTime,
      _endTime
    );

    return streamId;
  }

  function withdrawFromStream(uint256 _id, uint256 _amount) public {
    require(_amount > 0, 'Amount is zero');
    Stream memory stream = streamIdToStream[_id];

    // safemath?
    // compute available balance
    uint256 balance = uint256(
      (block.timestamp - stream.startTime) * stream.initialBalance
    ) /
      uint256(stream.endTime - stream.startTime) +
      stream.currentBalance -
      stream.initialBalance;
    require(balance >= _amount, 'Amount exceeds balance');

    streamIdToStream[_id].currentBalance =
      streamIdToStream[_id].currentBalance -
      _amount;

    if (streamIdToStream[_id].currentBalance == 0) delete streamIdToStream[_id];

    IERC20(stream.token).transfer(stream.destination, _amount);
    emit WithdrawnFromStream(_id, stream.destination, _amount);
  }

  function cancelStream(uint256 _id) public {
    Stream memory stream = streamIdToStream[_id];
    require(
      msg.sender == streamIdToStream[_id].source,
      'Only source can cancel'
    );
    uint256 recipientBalance = uint256(
      (block.timestamp - stream.startTime) * stream.initialBalance
    ) /
      uint256(stream.endTime - stream.startTime) +
      stream.currentBalance -
      stream.initialBalance;
    uint256 senderBalance = stream.initialBalance - recipientBalance;

    if (recipientBalance > 0) {
      IERC20(stream.token).transfer(stream.source, recipientBalance);
    }
    if (senderBalance > 0) {
      IERC20(stream.token).transfer(stream.destination, senderBalance);
    }
    delete streamIdToStream[_id];

    emit CancelledStream(
      _id,
      stream.source,
      stream.destination,
      senderBalance,
      recipientBalance
    );
  }
}
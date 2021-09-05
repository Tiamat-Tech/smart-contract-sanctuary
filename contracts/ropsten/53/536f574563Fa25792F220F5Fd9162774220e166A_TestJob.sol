// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import '../interfaces/external/IKeep3rV1.sol';

contract TestJob {
  uint32 public COOLDOWN = 3 minutes;
  uint256 public nonce;
  address keep3r;
  uint256 lastWork;

  error Cooldown();
  error NoKeeper();

  constructor(address _keep3r) {
    keep3r = _keep3r;
  }

  function workable() public view returns (bool) {
    return block.timestamp - lastWork > COOLDOWN;
  }

  function work() external validateAndPayKeeper(msg.sender) {
    if (!workable()) revert Cooldown();

    for (uint256 i = 0; i < 1000; i++) {
      nonce++;
    }

    lastWork = block.timestamp;
  }

  modifier validateAndPayKeeper(address _keeper) {
    if (!IKeep3rV1(keep3r).isKeeper(_keeper)) revert NoKeeper();
    _;
    IKeep3rV1(keep3r).worked(_keeper);
  }
}
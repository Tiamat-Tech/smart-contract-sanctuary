// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/governance/Governor.sol';
import '@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol';
import '@openzeppelin/contracts/governance/extensions/GovernorVotes.sol';

// Snippet from OpenZeppelin Wizard
contract ExchangeGovernor is Governor, GovernorCountingSimple, GovernorVotes {
  constructor(ERC20Votes _token) Governor('ExchangeGovernor') GovernorVotes(_token) {}

  function votingDelay() public pure override returns (uint256) {
    return 1; // 1 block
  }

  function votingPeriod() public pure override returns (uint256) {
    return 45818; // 1 week
  }

  function quorum(uint256 blockNumber) public pure override returns (uint256) {
    return blockNumber / blockNumber; // 1 For easy testing purposes only
  }

  // The following functions are overrides required by Solidity.

  function getVotes(address account, uint256 blockNumber) public view override(IGovernor, GovernorVotes) returns (uint256) {
    return super.getVotes(account, blockNumber);
  }
}
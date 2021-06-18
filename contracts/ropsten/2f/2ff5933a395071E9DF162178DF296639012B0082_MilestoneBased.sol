// SPDX-License-Identifier: MIT
pragma solidity =0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IVotingStrategy.sol";
import "./Roadmap.sol";
import "./Voting.sol";

contract MilestoneBased is UpgradeableBeacon {
  struct VotingInitialization {
    uint256 timeLockBeforeVoting;
    uint256 votingDuration;
    uint256 timeLockBeforeExecution;
  }

  mapping(address => bool) public isRoadmapByAddress;
  address[] public roadmaps;

  event RoadmapCreated(uint256 id, address roadmap);

  constructor(address _roadmapImplementation)
    UpgradeableBeacon(_roadmapImplementation)
  {} // solhint-disable-line no-empty-blocks

  function createRoadmap(
    uint256 _id,
    IERC20 _funds,
    IVotingStrategy _votingStrategy,
    address _refunding,
    Roadmap.FundsReleaseType _fundsReleaseType,
    address _admin,
    uint256[] memory _milestonesIds,
    uint256[] memory _milestonesAmounts,
    uint256[] memory _milestonesDates,
    VotingInitialization calldata _votingInitialization
  ) external {
    BeaconProxy roadmap = new BeaconProxy(address(this), "");
    Voting voting =
      new Voting(
        _votingStrategy,
        Roadmap(address(roadmap)),
        _votingInitialization.timeLockBeforeVoting,
        _votingInitialization.votingDuration,
        _votingInitialization.timeLockBeforeExecution
      );
    Roadmap(address(roadmap)).initialize(
      _id,
      _funds,
      address(voting),
      _refunding,
      _fundsReleaseType,
      _admin,
      _milestonesIds,
      _milestonesAmounts,
      _milestonesDates
    );

    isRoadmapByAddress[address(roadmap)] = true;
    roadmaps.push(address(roadmap));
    emit RoadmapCreated(_id, address(roadmap));
  }

  function roadmapsCount() external view returns (uint256) {
    return roadmaps.length;
  }

  function getRoadmapsRange(uint256 from, uint256 amount)
    external
    view
    returns (address[] memory)
  {
    address[] memory result = new address[](amount);
    uint256 to =
      (from + amount) > roadmaps.length ? roadmaps.length : from + amount;
    for (uint256 i = from; i < to; i++) {
      result[i - from] = roadmaps[i];
    }
    return result;
  }
}
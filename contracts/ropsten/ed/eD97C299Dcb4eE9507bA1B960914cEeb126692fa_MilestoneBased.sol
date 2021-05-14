// SPDX-License-Identifier: MIT
pragma solidity =0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/IBeacon.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./Roadmap.sol";

contract MilestoneBased is Ownable, IBeacon {
  address public roadmapImplementation;
  mapping(address => bool) public isRoadmapByAddress;
  address[] public roadmaps;

  event RoadmapImplementationChanged(address to);
  event RoadmapCreated(uint256 id, address roadmap);

  constructor(address _roadmapImplementation) {
    _setRoadmapImplementation(_roadmapImplementation);
  }

  function setRoadmapImplementation(address _roadmapImplementation)
    external
    onlyOwner
  {
    _setRoadmapImplementation(_roadmapImplementation);
  }

  function implementation() external view override returns (address) {
    return roadmapImplementation;
  }

  function createRoadmap(
    uint256 _id,
    IERC20 _funds,
    address _voting,
    address _refunding,
    Roadmap.FundsReleaseType _fundsReleaseType
  ) external {
    BeaconProxy roadmap = new BeaconProxy(address(this), "");
    Roadmap(address(roadmap)).initialize(
      _id,
      _funds,
      _voting,
      _refunding,
      _fundsReleaseType
    );

    isRoadmapByAddress[address(roadmap)] = true;
    roadmaps.push(address(roadmap));
    emit RoadmapCreated(_id, address(roadmap));
  }

  function roadmapsCount() external view returns (uint256) {
    return roadmaps.length;
  }

  function getRoadmapsRange(uint256 from, uint256 amount) external view returns (address[] memory) {
    address[] memory result = new address[](amount);
    uint256 to = (from + amount) > roadmaps.length ? roadmaps.length : from + amount;
    for (uint256 i = from; i < to; i++) {
      result[i - from] = roadmaps[i];
    }
    return result;
  }

  function _setRoadmapImplementation(address _roadmapImplementation) internal {
    require(
      Address.isContract(_roadmapImplementation),
      "Implementation is not a contract"
    );
    roadmapImplementation = _roadmapImplementation;
    emit RoadmapImplementationChanged(_roadmapImplementation);
  }
}
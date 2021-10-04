//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "hardhat/console.sol";

contract AwayMessage is Initializable, OwnableUpgradeable {
  using CountersUpgradeable for CountersUpgradeable.Counter;

  uint public maxMembers;
  uint public maxStatusLength;

  CountersUpgradeable.Counter public memberCount;
  CountersUpgradeable.Counter public statusCount;

  mapping (address => bool) private _members;
  mapping (address => string) private _statuses;
  mapping (address => uint) private _timestamps;
  mapping (address => CountersUpgradeable.Counter) private _counts;

  function initialize(uint256 _maxMembers, uint256 _maxStatusLength) public initializer {
    __Ownable_init();

    maxMembers = _maxMembers;
    maxStatusLength = _maxStatusLength;
  }

  function setMaxMembers(uint256 _maxMembers) public onlyOwner {
    console.log("Changing max members from '%s' to '%s'", maxMembers, _maxMembers);
    maxMembers = _maxMembers;
  }

  function setMaxStatusLength(uint256 _maxStatusLength) public onlyOwner {
    console.log("Changing max status length from '%s' to '%s'", maxStatusLength, _maxStatusLength);
    maxStatusLength = _maxStatusLength;
  }

  function getStatus(address _address) public view returns (string memory) {
    return _statuses[_address];
  }

  function getStatusCount(address _address) public view returns (uint256) {
    return _counts[_address].current();
  }

  function getStatusTimestamp(address _address) public view returns (uint256) {
    return _timestamps[_address];
  }

  function setStatus(string memory _status) public {
    uint length = bytes(_status).length;
    console.log("Setting new status with length '%s' for address '%s'", length, msg.sender);

    bool isMember = _isMember(msg.sender);

    if (!isMember) {
      console.log("User is not already a member");

      // Ensure we're not at member capacity.
      require(memberCount.current() < maxMembers, "AwayMessage: At maximum members");
    }

    // Check status length.
    require(length <= maxStatusLength, "AwayMessage: Status is too long");

    // Perform updates.
    _statuses[msg.sender] = _status;
    _timestamps[msg.sender] = block.timestamp;
    _counts[msg.sender].increment();

    statusCount.increment();

    if (!isMember) {
      _members[msg.sender] = true;
      
      memberCount.increment();
    }
  }

  function clearStatus() public {
    // Must be a recorded member.
    require(_isMember(msg.sender), "AwayMessage: Never set a status");

    // Clear status, keep timestamp the same.
    _statuses[msg.sender] = "";
  }

  function _hasStatus(address _address) internal view returns (bool) {
    return bytes(_statuses[_address]).length != 0;
  }

  function _isMember(address _address) internal view returns (bool) {
    return _members[_address];
  }
}
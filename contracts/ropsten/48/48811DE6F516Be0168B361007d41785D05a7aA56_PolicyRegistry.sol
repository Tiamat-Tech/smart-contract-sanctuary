// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./interfaces/IContractsRegistry.sol";
import "./interfaces/IPolicyBookFabric.sol";
import "./interfaces/IPolicyBookRegistry.sol";
import "./interfaces/IPolicyRegistry.sol";
import "./interfaces/IClaimingRegistry.sol";
import "./interfaces/IPolicyBook.sol";

import "./abstract/AbstractDependant.sol";

contract PolicyRegistry is IPolicyRegistry, AbstractDependant {
  using EnumerableSet for EnumerableSet.AddressSet;
  using SafeMath for uint256;
  using Math for uint256;
  
  IPolicyBookRegistry public policyBookRegistry;
  IClaimingRegistry public claimingRegistry;

  uint256 public constant STILL_CLAIMABLE_FOR = 1 days; // 1 weeks

  // User address => policy books array
  // mapping(address => address[]) public policies;
  mapping(address => EnumerableSet.AddressSet) private policies;

  // User address => policy book address
  mapping(address => mapping(address => PolicyInfo)) public policyInfos;

  event PolicyAdded(address _userAddr, address _policyBook, uint256 _coverAmount);
  event PolicyRemoved(address _userAddr, address _policyBook);

  function setDependencies(IContractsRegistry _contractsRegistry) external override onlyInjectorOrZero {
    policyBookRegistry = IPolicyBookRegistry(_contractsRegistry.getPolicyBookRegistryContract());
    claimingRegistry = IClaimingRegistry(_contractsRegistry.getClaimingRegistryContract());
  }

  function getPoliciesLength(address _userAddr) external override view returns (uint256) {
    return policies[_userAddr].length();
  }

  function policyExists(address _userAddr, address _policyBookAddr) external override view returns (bool) {
    return policies[_userAddr].contains(_policyBookAddr);
  }

  function isPolicyActive(address _userAddr, address _policyBookAddr) public override view returns (bool) {
    PolicyInfo storage _currentInfo = policyInfos[_userAddr][_policyBookAddr];

    if (_currentInfo.endTime == 0) {
      return false;
    }

    return _currentInfo.endTime.add(STILL_CLAIMABLE_FOR) > block.timestamp;
  }

  function policyStartTime(address _userAddr, address _policyBookAddr) public override view returns (uint256) {
    return policyInfos[_userAddr][_policyBookAddr].startTime;
  }

  function policyEndTime(address _userAddr, address _policyBookAddr) public override view returns (uint256) {
    return policyInfos[_userAddr][_policyBookAddr].endTime;
  }

  /// @dev use with getPoliciesLength()
  function getPoliciesInfo(address _userAddr, bool _isActive, uint256 _offset, uint256 _limit) 
    external 
    override
    view 
    returns (
      uint256 _policiesCount,
      address[] memory _policyBooksArr,
      PolicyInfo[] memory _policies,
      IClaimingRegistry.ClaimStatus[] memory _policyStatuses
    )
  {    
    EnumerableSet.AddressSet storage _totalPolicyBooksArr = policies[_userAddr];

    uint256 to = (_offset.add(_limit)).min(_totalPolicyBooksArr.length()).max(_offset);
    uint256 size = to - _offset;

    _policyBooksArr = new address[](size);
    _policies = new PolicyInfo[](size);
    _policyStatuses = new IClaimingRegistry.ClaimStatus[](size);

    for (uint256 i = _offset; i < to; i++) {
      address _currentPolicyBookAddress = _totalPolicyBooksArr.at(i);
      if (_isActive && isPolicyActive(_userAddr, _currentPolicyBookAddress)) {
        _policies[_policiesCount] = policyInfos[_userAddr][_currentPolicyBookAddress];
        _policyStatuses[_policiesCount] = claimingRegistry.policyStatus(_userAddr, _currentPolicyBookAddress); 
        _policyBooksArr[_policiesCount] = _currentPolicyBookAddress;
        _policiesCount++; 
      } else if (!_isActive && !isPolicyActive(_userAddr, _currentPolicyBookAddress)) {
        _policies[_policiesCount] = policyInfos[_userAddr][_currentPolicyBookAddress];
        _policyStatuses[_policiesCount] = IClaimingRegistry.ClaimStatus.UNCLAIMABLE;
        _policyBooksArr[_policiesCount] = _currentPolicyBookAddress;
        _policiesCount++;   
      }
    }
  }

  function getUsersInfo(address[] calldata _users, address[] calldata _policyBooks) 
    external
    view 
    override
    returns (
      PolicyUserInfo[] memory _usersInfos
    )
  {
    require (_users.length == _policyBooks.length, "PolicyBookRegistry: Lengths' mismatch");

    _usersInfos = new PolicyUserInfo[](_users.length);  

    IPolicyBook.PolicyHolder memory policyHolder;
    
    for (uint256 i = 0; i < _users.length; i++) {
      require (policyBookRegistry.isPolicyBook(_policyBooks[i]), 
        "PolicyRegistry: Provided address is not a PolicyBook");

      policyHolder = IPolicyBook(_policyBooks[i]).userStats(_users[i]);      

      (_usersInfos[i].name, 
      _usersInfos[i].insuredContract,
      _usersInfos[i].contractType, ) = IPolicyBook(_policyBooks[i]).stats();

      bool isActive = isPolicyActive(_users[i], _policyBooks[i]);
      
      _usersInfos[i].coverTokens = policyHolder.coverTokens;
      _usersInfos[i].startTime = isActive ? policyStartTime(_users[i], _policyBooks[i]) : 0;
      _usersInfos[i].endTime = isActive ? policyEndTime(_users[i], _policyBooks[i]) : 0;
      _usersInfos[i].payed = policyHolder.payed;
    }
  }

  function addPolicy(
    address _userAddr,
    uint256 _coverAmount,
    uint256 _premium,
    uint256 _durationSeconds
  ) 
    external override onlyPolicyBooks
  {
    require(!isPolicyActive(_userAddr, msg.sender), "PolicyRegistry: The policy already exists");

    if (!policies[_userAddr].contains(msg.sender)) {
      policies[_userAddr].add(msg.sender);
    }

    policyInfos[_userAddr][msg.sender] = PolicyInfo(
      _coverAmount,
      _premium,
      block.timestamp,
      block.timestamp.add(_durationSeconds)
    );

    emit PolicyAdded(_userAddr, msg.sender, _coverAmount);
  }

  function getPoliciesArr(address _userAddr) external view returns (address[] memory _arr) {
    uint256 _size = policies[_userAddr].length();
    _arr = new address[](_size);

    for (uint256 i = 0; i < _size; i++) {
      _arr[i] = policies[_userAddr].at(i);
    }
  }

  function removePolicy(address _userAddr)
    external 
    override 
    onlyPolicyBooks 
  {
    require(policyInfos[_userAddr][msg.sender].startTime != 0, "PolicyRegistry: This policy is not on the list");

    delete policyInfos[_userAddr][msg.sender];

    policies[_userAddr].remove(msg.sender);

    emit PolicyRemoved(_userAddr, msg.sender);
  }

  modifier onlyPolicyBooks() {
    require(policyBookRegistry.isPolicyBook(msg.sender),
      "PolicyRegistry: The caller does not have access");
    _;
  }
}
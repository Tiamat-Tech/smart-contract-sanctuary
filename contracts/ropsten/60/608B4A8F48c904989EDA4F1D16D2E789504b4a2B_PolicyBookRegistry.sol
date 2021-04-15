// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IPolicyBook.sol";
import "./interfaces/IPolicyBookRegistry.sol";
import "./interfaces/IContractsRegistry.sol";

import "./abstract/AbstractDependant.sol";

contract PolicyBookRegistry is IPolicyBookRegistry, AbstractDependant {
  using Math for uint256;
  using SafeMath for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;  

  address public policyBookFabricAddress;

  // insured contract address => proxy address
  mapping(address => address) public policiesByInsuredAddress;
  EnumerableSet.AddressSet private policies;

  event Added(address insured, address at);

  modifier onlyPolicyBookFabric() {
    require(msg.sender == policyBookFabricAddress, 
      "PolicyBookRegistry: Caller is not a PolicyBookFabric contract");
    _;
  }

  function setDependencies(IContractsRegistry _contractsRegistry) external override onlyInjectorOrZero {
    policyBookFabricAddress = _contractsRegistry.getPolicyBookFabricContract();
  }

  function add(address _insuredContract, address _policyBook) external override onlyPolicyBookFabric {
    require(policiesByInsuredAddress[_insuredContract] == address(0),
      "PolicyBookRegistry: PolicyBook for the contract is already created");

    policies.add(_policyBook);
    policiesByInsuredAddress[_insuredContract] = _policyBook;

    emit Added(_insuredContract, _policyBook);
  }

  function isPolicyBook(address _contract) public view override returns (bool) {
    return policies.contains(_contract);
  }

  function count() external view override returns (uint256) {
    return policies.length();
  }

  /// @dev the order of policyBooks might change
  function list(uint256 _offset, uint256 _limit)
    public
    view
    override
    returns (address[] memory _policyBooks)
  {
    uint256 to = (_offset.add(_limit)).min(policies.length()).max(_offset);

    _policyBooks = new address[](to - _offset);

    for (uint256 i = _offset; i < to; i++) {
      _policyBooks[i - _offset] = policies.at(i);
    }
  }

  function listWithStats(uint256 _offset, uint256 _limit)
    external
    view
    override
    returns (
      address[] memory _policyBooks,
      PolicyBookStats[] memory _stats
    )
  {
    _policyBooks = list(_offset, _limit);
    _stats = stats(_policyBooks);
  }

  function policyBookFor(address _contract) external view override returns (address) {
    return policiesByInsuredAddress[_contract];
  }

  function stats(address[] memory _policyBooks)
    public
    view
    override
    returns (
      PolicyBookStats[] memory _stats
    )
  {
    _stats = new PolicyBookStats[](_policyBooks.length);    
    
    for (uint256 i = 0; i < _policyBooks.length; i++) {
      require (isPolicyBook(_policyBooks[i]), "PolicyBookRegistry: Provided address is not a PolicyBook");

      (_stats[i].name, 
      _stats[i].insuredContract,
      _stats[i].contractType,
      _stats[i].whitelisted) = IPolicyBook(_policyBooks[i]).stats();
      
      (_stats[i].maxCapacity,
      _stats[i].totalDaiLiquidity,
      _stats[i].APY) = IPolicyBook(_policyBooks[i]).numberStats();
    }    
  }

  function statsByInsuredContracts(address[] calldata _insuredContracts)
    external
    view
    override
    returns (      
      PolicyBookStats[] memory _stats
    )
  {
    _stats = new PolicyBookStats[](_insuredContracts.length);  
    
    for (uint256 i = 0; i < _insuredContracts.length; i++) {
      (_stats[i].name, 
      _stats[i].insuredContract,
      _stats[i].contractType,
      _stats[i].whitelisted) = IPolicyBook(policiesByInsuredAddress[_insuredContracts[i]]).stats();
      
      (_stats[i].maxCapacity,
      _stats[i].totalDaiLiquidity,
      _stats[i].APY) = IPolicyBook(policiesByInsuredAddress[_insuredContracts[i]]).numberStats();
    }
  }
}
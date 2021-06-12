// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interface/IBookkeeper.sol";
import "./Controllable.sol";

contract Bookkeeper is IBookkeeper, Initializable, Controllable {

  string public constant VERSION = "0";

  // DO NOT CHANGE NAMES OR ORDERING!
  address[] public vaults;
  address[] public strategies;
  mapping(address => uint256) public targetTokenEarned;
  mapping(address => mapping(uint256 => uint256)) public doHardWorkCalls;
  mapping(address => uint256) public lastDoHardWorkCall;

  function initialize(address _controller) public initializer {
    Controllable.initializeControllable(_controller);
  }

  modifier onlyStrategy() {
    require(IController(controller()).strategies(msg.sender), "only exist strategy");
    _;
  }

  function addVault(address _vault) external override onlyControllerOrGovernance {
    vaults.push(_vault);
  }

  function addStrategy(address _strategy) external override onlyControllerOrGovernance {
    strategies.push(_strategy);
  }

  function registerStrategyEarned(uint256 _targetTokenAmount) external override onlyStrategy {
    targetTokenEarned[msg.sender] += _targetTokenAmount;
    doHardWorkCalls[msg.sender][block.timestamp] += _targetTokenAmount;
    lastDoHardWorkCall[msg.sender] = block.timestamp;
  }

  function isGovernance(address _contract) external override view returns (bool) {
    return IController(controller()).isGovernance(_contract);
  }

}
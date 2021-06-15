// SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interface/IBookkeeper.sol";
import "./Controllable.sol";
import "../interface/IGovernable.sol";

contract Bookkeeper is IBookkeeper, Initializable, Controllable, IGovernable {

  string public constant VERSION = "0";

  // DO NOT CHANGE NAMES OR ORDERING!
  address[] private _vaults;
  address[] private _strategies;
  mapping(address => uint256) public targetTokenEarned;
  mapping(address => mapping(uint256 => uint256)) public doHardWorkCalls;
  mapping(address => uint256) public lastDoHardWorkCall;
  mapping(address => mapping(address => uint256)) public vaultUsers;
  mapping(address => uint256) public vaultUsersQuantity;

  event RegisterVault(address value);
  event RegisterStrategy(address value);
  event RegisterStrategyEarned(uint256 amount);
  event RegisterUserAction(address user, uint256 amount, bool deposit);

  function initialize(address _controller) public initializer {
    Controllable.initializeControllable(_controller);
  }

  modifier onlyStrategy() {
    require(IController(controller()).strategies(msg.sender), "only exist strategy");
    _;
  }

  modifier onlyVault() {
    require(IController(controller()).vaults(msg.sender), "only exist vault");
    _;
  }

  function addVault(address _vault) external override onlyControllerOrGovernance {
    _vaults.push(_vault);
    emit RegisterVault(_vault);
  }

  function addStrategy(address _strategy) external override onlyControllerOrGovernance {
    _strategies.push(_strategy);
    emit RegisterStrategy(_strategy);
  }

  function registerStrategyEarned(uint256 _targetTokenAmount) external override onlyStrategy {
    targetTokenEarned[msg.sender] += _targetTokenAmount;
    doHardWorkCalls[msg.sender][block.timestamp] += _targetTokenAmount;
    lastDoHardWorkCall[msg.sender] = block.timestamp;
    emit RegisterStrategyEarned(_targetTokenAmount);
  }

  function registerUserAction(address _user, uint256 _amount, bool _deposit)
  external override onlyVault {
    if (vaultUsers[msg.sender][_user] == 0) {
      vaultUsersQuantity[msg.sender] += 1;
    }
    if (_deposit) {
      vaultUsers[msg.sender][_user] += _amount;
    } else {
      vaultUsers[msg.sender][_user] -= _amount;
    }
    if (vaultUsers[msg.sender][_user] == 0) {
      vaultUsersQuantity[msg.sender] -= 1;
    }
    emit RegisterUserAction(_user, _amount, _deposit);
  }

  function isGovernance(address _contract) external override view returns (bool) {
    return IController(controller()).isGovernance(_contract);
  }

  function vaults() external override view returns (address[] memory) {
    return _vaults;
  }

  function strategies() external override view returns (address[] memory) {
    return _strategies;
  }

}
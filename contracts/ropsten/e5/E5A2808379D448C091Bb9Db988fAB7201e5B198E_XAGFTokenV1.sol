// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

import '../access/AccessFlags.sol';
import '../access/interfaces/IMarketAccessController.sol';

import './locker/DecayingTokenLocker.sol';
import '../tools/upgradeability/VersionedInitializable.sol';
import './interfaces/IInitializableRewardToken.sol';
import '../access/interfaces/IRemoteAccessBitmask.sol';
import './interfaces/IRewardController.sol';
import '../tools/math/WadRayMath.sol';

contract XAGFTokenV1 is IInitializableRewardToken, DecayingTokenLocker, VersionedInitializable {
  string internal constant NAME = 'Augmented Finance Locked Reward Token';
  string internal constant SYMBOL = 'xAGF';
  uint8 internal constant DECIMALS = 18;

  string private _name;
  string private _symbol;
  uint8 private _decimals;

  uint256 private constant TOKEN_REVISION = 1;

  constructor() DecayingTokenLocker(IRewardController(address(this)), 0, 0, address(0)) {
    _initializeERC20(NAME, SYMBOL, DECIMALS);
  }

  function _initializeERC20(
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) internal {
    _name = name_;
    _symbol = symbol_;
    _decimals = decimals_;
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function getRevision() internal pure virtual override returns (uint256) {
    return TOKEN_REVISION;
  }

  function getPoolName() public view override returns (string memory) {
    return _symbol;
  }

  // This initializer is invoked by AccessController.setAddressAsImpl
  function initialize(IMarketAccessController ac) external virtual initializer(TOKEN_REVISION) {
    address controller = ac.getAddress(AccessFlags.REWARD_CONTROLLER);
    address underlying = ac.getAddress(AccessFlags.REWARD_TOKEN);

    _initializeERC20(NAME, SYMBOL, DECIMALS);
    super._initialize(underlying);
    super._initialize(IRewardController(controller), 0, 0);
  }

  function initialize(InitData calldata data)
    external
    virtual
    override
    initializer(TOKEN_REVISION)
  {
    IMarketAccessController ac = IMarketAccessController(address(data.remoteAcl));
    address controller = ac.getAddress(AccessFlags.REWARD_CONTROLLER);
    address underlying = ac.getAddress(AccessFlags.REWARD_TOKEN);

    _initializeERC20(data.name, data.symbol, data.decimals);
    super._initialize(underlying);
    super._initialize(IRewardController(controller), 0, 0);
  }

  function initializeToken(
    IMarketAccessController remoteAcl,
    address underlying,
    string calldata name_,
    string calldata symbol_,
    uint8 decimals_
  ) public virtual initializer(TOKEN_REVISION) {
    address controller = remoteAcl.getAddress(AccessFlags.REWARD_CONTROLLER);

    _initializeERC20(name_, symbol_, decimals_);
    super._initialize(underlying);
    super._initialize(IRewardController(controller), 0, 0);
  }

  function initializePool(
    IRewardController controller,
    address underlying,
    uint256 initialRate,
    uint16 baselinePercentage
  ) public virtual initializer(TOKEN_REVISION) {
    _initializeERC20(NAME, SYMBOL, DECIMALS);
    super._initialize(underlying);
    super._initialize(controller, initialRate, baselinePercentage);
  }
}
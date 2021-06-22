//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;

import "../base/strategies/NoopStrategy.sol";
import "../base/interface/ISmartVault.sol";


contract MockStrategyQuickSushiRopsten is StrategyBase {

  string private constant _PLATFORM = "MOCK_STRATEGIES";
  address public constant SUSHI_MockSUSHI_MockQUICK = address(0xA8818F63D2dd524E38f14E6A70163aBB957DcFe9);
  address public constant MockQUICK = address(0x48526Fb38CA3ed2c4c7e617ABDe3804edaDe8b4f);
  address public constant MockSUSHI = address(0xcD68bD1Ae4511F264a922BfbB396f72D6E89f245);

  address[] private rewards = [MockSUSHI];
  address[] private _assets = [SUSHI_MockSUSHI_MockQUICK, MockQUICK, MockSUSHI];

  string public constant VERSION = "0";
  string public constant STRATEGY_TYPE = "MockStrategy";
  uint256 private constant BUY_BACK_RATIO = 10000;

  address public pool;

  constructor(
    address _controller,
    address _vault,
    address _pool
  ) StrategyBase(_controller, SUSHI_MockSUSHI_MockQUICK, _vault, rewards, BUY_BACK_RATIO) {
    pool = _pool;
  }

  function rewardPoolBalance() public override view returns (uint256 bal) {
    bal = IERC20(pool).balanceOf(pool);
  }

  function doHardWork() external onlyNotPausedInvesting override restricted {
    exitRewardPool();
    liquidateReward();
    investAllUnderlying();
  }

  function isZeroAddressPool() internal override view returns (bool) {
    return address(pool) == address(0);
  }

  function depositToPool(uint256 amount) internal override {
    IERC20(_underlyingToken).approve(pool, 0);
    IERC20(_underlyingToken).approve(pool, amount);
    ISmartVault(pool).deposit(amount);
  }

  function withdrawAndClaimFromPool(uint256) internal override {
    ISmartVault(pool).exit();
  }

  function emergencyWithdrawFromPool() internal override {
    ISmartVault(pool).withdraw(rewardPoolBalance());
  }

  function liquidateReward() internal override {
    liquidateRewardDefault();
  }

  function platform() external override pure returns (string memory) {
    return _PLATFORM;
  }

  function assets() external override view returns (address[] memory) {
    return _assets;
  }
}
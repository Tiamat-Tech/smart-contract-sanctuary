/**
 *Submitted for verification at moonriver.moonscan.io on 2022-01-12
 */

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CCCTokenDistribution is Pausable, Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  uint256 public TGEDate;
  IERC20 public token;

  struct DistributionStep {
    address wallet;
    uint256 unlockStarted;
    uint256 unlockEnded;
    uint256 amountSend;
    bool sent;
  }

  DistributionStep[] private distributions;

  mapping(address => uint256) private amountDistributions;

  constructor(IERC20 _token) {
    token = _token;
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function getDistributedAmount(address _wallet) public view returns (uint256) {
    require(_wallet != address(0), "wallet address is invalid");
    return amountDistributions[_wallet];
  }

  function getDistributionCount() public view returns (uint256) {
    return distributions.length;
  }

  function getDistribution(uint256 index)
    public
    view
    returns (
      address,
      uint256,
      uint256,
      uint256
    )
  {
    return (
      distributions[index].wallet,
      distributions[index].unlockStarted,
      distributions[index].unlockEnded,
      distributions[index].amountSend
    );
  }

  function startDistribution(uint256 _TGEDate)
    external
    onlyOwner
    whenNotPaused
  {
    TGEDate = _TGEDate;
  }

  function setDistributionConfig(
    address _wallet,
    uint256 _unlockStarted,
    uint256 _unlockEnded,
    uint256 _amountSend
  ) external onlyOwner whenNotPaused nonReentrant {
    require(_wallet != address(0), "wallet address is invalid");
    require(_wallet != owner(), "wallet address is owner's");
    DistributionStep memory distribution = DistributionStep(
      _wallet,
      _unlockStarted,
      _unlockEnded,
      _amountSend,
      false
    );
    distributions.push(distribution);
  }

  function tryDistribution() external onlyOwner whenNotPaused nonReentrant {
    require(TGEDate != 0, "TGE Date is not set yet");
    require(block.timestamp >= TGEDate, "The distribution is not started");
    uint256 count = distributions.length;
    for (uint256 i = 0; i < count; i++) {
      if (
        !distributions[i].sent &&
        block.timestamp >= distributions[i].unlockStarted &&
        block.timestamp < distributions[i].unlockEnded
      ) {
        uint256 amount = distributions[i].amountSend;
        require(token.transfer(distributions[i].wallet, amount));
        amountDistributions[distributions[i].wallet] = amountDistributions[
          distributions[i].wallet
        ].add(amount);
        distributions[i].sent = true;
      }
    }
  }
}
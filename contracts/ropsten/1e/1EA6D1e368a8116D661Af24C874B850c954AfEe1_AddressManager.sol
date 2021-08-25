//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/IAddressManager.sol";

/**
 * @title Address Manager contract
 * @author Maxos
 */
contract AddressManager is IAddressManager, OwnableUpgradeable {
  /*** Storage Properties ***/

  // Maxos manager address
  address public override manager;

  // Maxos contracts
  address public override bankerContract;
  address public override treasuryContract;

  // Maxos tokens
  address public override maxUSD;
  address public override maxBanker;

  // Investor
  address public override investor;

  // Strategies
  address public override yearnUSDCStrategy;

  /*** Contract Logic Starts Here */

  function initialize(address _manager) public initializer {
    __Ownable_init();

    manager = _manager;
  }

  /**
   * @notice Set manager
   * @param _manager Manager address
   */
  function setManager(address _manager) external onlyOwner {
    manager = _manager;
  }

  /**
   * @notice Set banker contract address
   * @param _bankerContract Banker contract address
   */
  function setBankerContract(address _bankerContract) external onlyOwner {
    bankerContract = _bankerContract;
  }

  /**
   * @notice Set treasury contract address
   * @param _treasuryContract Treasury contract address
   */
  function setTreasuryContract(address _treasuryContract) external onlyOwner {
    treasuryContract = _treasuryContract;
  }

  /**
   * @notice Set MaxUSD token address
   * @param _maxUSD MaxUSD token address
   */
  function setMaxUSD(address _maxUSD) external onlyOwner {
    maxUSD = _maxUSD;
  }

  /**
   * @notice Set MaxBanker token address
   * @param _maxBanker MaxBanker token address
   */
  function setMaxBanker(address _maxBanker) external onlyOwner {
    maxBanker = _maxBanker;
  }

  /**
   * @notice Set investor address
   * @param _investor Investor wallet address
   */
  function setInvestor(address _investor) external onlyOwner {
    investor = _investor;
  }

  /**
   * @notice Set Yearn USDC Strategy address
   * @param _yearnUSDCStrategy Yearn USDC Strategy address
   */
  function setYearnUSDCStrategy(address _yearnUSDCStrategy) external onlyOwner {
    yearnUSDCStrategy = _yearnUSDCStrategy;
  }
}
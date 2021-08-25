//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IBanker.sol";
import "../interfaces/IERC20Extended.sol";
import "../interfaces/IAddressManager.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IStrategyAssetValue.sol";

/**
 * @notice Treasury Contract
 * @author Maxos
 */
contract Treasury is ITreasury, IStrategyAssetValue, ReentrancyGuardUpgradeable {
  /*** Events ***/

  event AllowToken(address indexed token);
  event DisallowToken(address indexed token);

  /*** Storage Properties ***/

  // Token list allowed in treasury
  address[] public allowedTokens;

  // Returns if token is allowed
  mapping(address => bool) public isAllowedToken;

  // MaxUSD scaled balance
  // userScaledBalance = userBalance / currentInterestIndex
  // This essentially `marks` when a user has deposited in the treasury and can be used to calculate the users current redeemable balance
  mapping(address => uint256) public userScaledBalance;

  // Address manager
  address public addressManager;

  /*** Contract Logic Starts Here */

  modifier onlyManager() {
    require(msg.sender == IAddressManager(addressManager).manager(), "No manager");
    _;
  }

  function initialize(address _addressManager) public initializer {
    __ReentrancyGuard_init();

    addressManager = _addressManager;
  }

  /**
   * @notice Deposit token to the protocol
   * @dev Only allowed token can be deposited
   * @dev Mint MaxUSD and MaxBanker according to mintDepositPercentage
   * @dev Increase user's insurance if mintDepositPercentage is [0, 100)
   * @param _token token address
   * @param _amount token amount
   */
  function buyDeposit(address _token, uint256 _amount) external override onlyManager {
    // TODO: Remove onlyManager modifier later
    require(isAllowedToken[_token], "Invalid token");

    // transfer token
    require(IERC20Upgradeable(_token).transferFrom(msg.sender, address(this), _amount));

    // mint MaxUSD/MaxBanker tokens according to the mintDepositPercentage
    // uint256 mintDepositPercentage = IBanker(IAddressManager(addressManager).bankerContract()).mintDepositPercentage();

    // Increase MaxUSDLiabilities
    IBanker(IAddressManager(addressManager).bankerContract()).increaseMaxUSDLiabilities(_amount);
  }

  /**
   * @notice Withdraw token from the protocol
   * @dev Only allowed token can be withdrawn
   * @dev Decrease user's insurance if _token is MaxBanker
   * @param _amount token amount
   */
  function redeemDeposit(uint256 _amount) external override nonReentrant onlyManager {
    // TODO: Remove onlyManager modifier later
    require(_amount <= IBanker(IAddressManager(addressManager).bankerContract()).getUserMaxUSDLiability(msg.sender), "Invalid amount");

    IBanker(IAddressManager(addressManager).bankerContract()).addRedemptionRequest(msg.sender, _amount, block.timestamp);

    // // transfer token 
    // require(IERC20Upgradeable(_token).transfer(msg.sender, _amount));
  }

  /**
   * @notice Add a new token into the allowed token list
   * @param _token Token address
   */
  function allowToken(address _token) external override onlyManager {
    require(!isAllowedToken[_token], "Already allowed");
    isAllowedToken[_token] = true;

    allowedTokens.push(_token);

    // approve infinit amount of tokens to banker contract
    IERC20Upgradeable(_token).approve(IAddressManager(addressManager).bankerContract(), type(uint256).max);

    emit AllowToken(_token);
  }

  /**
   * @notice Remove token from the allowed token list
   * @param _token Token index in the allowed token list
   */
  function disallowToken(address _token) external override onlyManager {
    require(isAllowedToken[_token], "Already disallowed");
    isAllowedToken[_token] = false;

    for (uint256 i; i < allowedTokens.length; i++) {
      if (allowedTokens[i] == _token) {
        allowedTokens[i] = allowedTokens[allowedTokens.length - 1];
        allowedTokens.pop();

        // remove allowance to banker contract
        IERC20Upgradeable(_token).approve(IAddressManager(addressManager).bankerContract(), 0);

        break;
      }
    }

    emit DisallowToken(_token);
  }

  /**
   * @notice Returns asset value of the Treasury
   * @return (uint256) asset value of the Treasury in USD, Ex: 100 USD is represented by 10,000
   */
  function strategyAssetValue() external view override returns (uint256) {
    uint256 assetValue;
    for (uint256 i; i < allowedTokens.length; i++) {
      assetValue += IERC20Upgradeable(allowedTokens[i]).balanceOf(address(this)) * 100 / (10**IERC20Extended(allowedTokens[i]).decimals());
    }

    return assetValue;
  }
}
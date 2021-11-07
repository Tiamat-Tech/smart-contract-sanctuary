// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract CROSToken is Initializable, OwnableUpgradeable, ERC20Upgradeable {
  uint256 private constant _NOMINATOR = 10000;
  uint256 public supply;

  address public marketingDevelopment;
  address public privateSale;
  address public publicSale;
  address public treasury;
  address public floatLiquidity;
  address public liquidityMining;
  address public team;
  address public advisors;
  address public ecoSystemFunds;

  // track Withdraw
  uint256 public marketingDevelopmentWithdraw;
  uint256 public privateSaleWithdraw;
  uint256 public publicSaleWithdraw;
  uint256 public treasuryWithdraw;
  uint256 public floatLiquidityWithdraw;
  uint256 public liquidityMiningWithdraw;
  uint256 public teamWithdraw;
  uint256 public advisorsWithdraw;
  uint256 public ecoSystemFundsWithdraw;

  // percentages
  uint256 private constant MARKETING_DEVELOPMENT_PERCENTAGE = 1500;
  uint256 private constant PRIVATE_SALE_PERCENTAGE = 830;
  uint256 private constant PUBLIC_SALE_PERCENTAGE = 170;
  uint256 private constant TREASURY_PERCENTAGE = 1000;
  uint256 private constant FLOAT_LIQUIDITY_PERCENTAGE = 200;
  uint256 private constant LIQUIDITY_MINING_PERCENTAGE = 1500;
  uint256 private constant TEAM_PERCENTAGE = 1100;
  uint256 private constant ADVISORS_PERCENTAGE = 800;
  uint256 private constant ECOSYSTEM_FUNDS_PERCENTAGE = 2900;

  function __CROSToken_init(
    uint256 _supply,
    address _marketingDevelopment,
    address _privateSale,
    address _publicSale,
    address _treasury,
    address _floatLiquidity,
    address _liquidityMining,
    address _team,
    address _advisors,
    address _ecoSystemFunds
  ) public initializer {
    __Ownable_init();
    __ERC20_init("CROS", "CROS");
    supply = _supply;
    marketingDevelopment = _marketingDevelopment;
    privateSale = _privateSale;
    publicSale = _publicSale;
    treasury = _treasury;
    floatLiquidity = _floatLiquidity;
    liquidityMining = _liquidityMining;
    team = _team;
    advisors = _advisors;
    ecoSystemFunds = _ecoSystemFunds;
  }

  /**
   * @dev withdraw markenting funds
   * @param _amount total amount to withdraw
   */
  function withdrawMarketingDevelopmentFunds(uint256 _amount) external {
    require(msg.sender == marketingDevelopment, "wrong owner");

    uint256 total = (supply * MARKETING_DEVELOPMENT_PERCENTAGE) / _NOMINATOR;
    require(_amount <= (total - marketingDevelopmentWithdraw), "wrong amount");

    _mint(marketingDevelopment, _amount);
    marketingDevelopmentWithdraw = marketingDevelopmentWithdraw + _amount;
  }

  /**
   * @dev withdraw private sale funds
   * @param _amount total amount to withdraw
   */
  function withdrawPrivateSaleFunds(uint256 _amount) external {
    require(msg.sender == privateSale, "wrong owner");

    uint256 total = (supply * PRIVATE_SALE_PERCENTAGE) / _NOMINATOR;
    require(_amount <= (total - privateSaleWithdraw), "wrong amount");

    _mint(privateSale, _amount);
    privateSaleWithdraw = privateSaleWithdraw + _amount;
  }

  /**
   * @dev withdraw public sale funds
   * @param _amount total amount to withdraw
   */
  function withdrawPublicSaleFunds(uint256 _amount) external {
    require(msg.sender == publicSale, "wrong owner");

    uint256 total = (supply * PUBLIC_SALE_PERCENTAGE) / _NOMINATOR;
    require(_amount <= (total - publicSaleWithdraw), "wrong amount");

    _mint(publicSale, _amount);
    publicSaleWithdraw = publicSaleWithdraw + _amount;
  }

  /**
   * @dev withdraw treasury funds
   * @param _amount total amount to withdraw
   */
  function withdrawTreasuryFunds(uint256 _amount) external {
    require(msg.sender == treasury, "wrong owner");

    uint256 total = (supply * TREASURY_PERCENTAGE) / _NOMINATOR;
    require(_amount <= (total - treasuryWithdraw), "wrong amount");

    _mint(treasury, _amount);
    treasuryWithdraw = treasuryWithdraw + _amount;
  }

  /**
   * @dev withdraw float liquidity funds
   * @param _amount total amount to withdraw
   */
  function withdrawFloatLiquidityFunds(uint256 _amount) external {
    require(msg.sender == floatLiquidity, "wrong owner");

    uint256 total = (supply * FLOAT_LIQUIDITY_PERCENTAGE) / _NOMINATOR;
    require(_amount <= (total - floatLiquidityWithdraw), "wrong amount");

    _mint(floatLiquidity, _amount);
    floatLiquidityWithdraw = floatLiquidityWithdraw + _amount;
  }

  /**
   * @dev withdraw liquidity mining funds
   * @param _amount total amount to withdraw
   */
  function withdrawLiquidityMiningFunds(uint256 _amount) external {
    require(msg.sender == liquidityMining, "wrong owner");

    uint256 total = (supply * LIQUIDITY_MINING_PERCENTAGE) / _NOMINATOR;
    require(_amount <= (total - liquidityMiningWithdraw), "wrong amount");

    _mint(liquidityMining, _amount);
    liquidityMiningWithdraw = liquidityMiningWithdraw + _amount;
  }

  /**
   * @dev withdraw team funds
   * @param _amount total amount to withdraw
   */
  function withdrawTeamFunds(uint256 _amount) external {
    require(msg.sender == team, "wrong owner");

    uint256 total = (supply * TEAM_PERCENTAGE) / _NOMINATOR;
    require(_amount <= (total - teamWithdraw), "wrong amount");

    _mint(team, _amount);
    teamWithdraw = teamWithdraw + _amount;
  }

  /**
   * @dev withdraw advisors funds
   * @param _amount total amount to withdraw
   */
  function withdrawAdvisorsFunds(uint256 _amount) external {
    require(msg.sender == advisors, "wrong owner");

    uint256 total = (supply * ADVISORS_PERCENTAGE) / _NOMINATOR;
    require(_amount <= (total - advisorsWithdraw), "wrong amount");

    _mint(advisors, _amount);
    advisorsWithdraw = advisorsWithdraw + _amount;
  }

  /**
   * @dev withdraw ecosystem funds
   * @param _amount total amount to withdraw
   */
  function withdrawEcosystemFunds(uint256 _amount) external {
    require(msg.sender == ecoSystemFunds, "wrong owner");

    uint256 total = (supply * ECOSYSTEM_FUNDS_PERCENTAGE) / _NOMINATOR;
    require(_amount <= (total - ecoSystemFundsWithdraw), "wrong amount");

    _mint(ecoSystemFunds, _amount);
    ecoSystemFundsWithdraw = ecoSystemFundsWithdraw + _amount;
  }
}
//SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "../base/governance/Controllable.sol";
import "../base/interface/IBookkeeper.sol";
import "../base/interface/ISmartVault.sol";
import "../base/interface/IGovernable.sol";
import "../base/interface/IStrategy.sol";
import "./IPriceCalculator.sol";

contract ContractReader is IGovernable, Initializable, Controllable {
  using SafeMath for uint256;

  string public constant VERSION = "0";
  uint256 constant public PRECISION = 10 ** 18;
  mapping(bytes32 => address) internal tools;

  function initialize(address _controller) public initializer {
    Controllable.initializeControllable(_controller);
  }

  event ToolAddressUpdated(address newValue);

  struct VaultInfo {
    address addr;
    string name;
    uint256 created;
    bool active;
    uint256 tvl;
    uint256 tvlUsdc;
    uint256 decimals;
    address underlying;
    address[] rewardTokens;
    uint256[] rewardTokensBal;
    uint256[] rewardTokensBalUsdc;
    uint256 duration;
    uint256[] rewardsApr;
    uint256 ppfsApr;
    uint256 users;

    // strategy
    address strategy;
    uint256 strategyCreated;
    string platform;
    address[] assets;
    address[] strategyRewards;
    bool strategyOnPause;
    uint256 earned;
  }

  struct UserInfo {
    address wallet;
    address vault;
    uint256 balance;
    uint256 balanceUsdc;
    address[] rewardTokens;
    uint256[] rewards;
    uint256[] rewardsUsdc;
  }

  // **************************************************************
  // HEAVY QUERIES
  //***************************************************************

  function vaultInfos() public view returns (VaultInfo[] memory) {
    VaultInfo[] memory result = new VaultInfo[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = vaultInfo(vaults()[i]);
    }
    return result;
  }

  function vaultInfo(address vault) public view returns (VaultInfo memory) {
    address strategy = ISmartVault(vault).strategy();
    VaultInfo memory v = VaultInfo(
      vault,
      vaultName(vault),
      vaultCreated(vault),
      vaultActive(vault),
      vaultTvl(vault),
      vaultTvlUsdc(vault),
      vaultDecimals(vault),
      vaultUnderlying(vault),
      vaultRewardTokens(vault),
      vaultRewardTokensBal(vault),
      vaultRewardTokensBalUsdc(vault),
      vaultDuration(vault),
      vaultRewardsApr(vault),
      vaultPpfsApr(vault),
      vaultUsers(vault),
      strategy,
      strategyCreated(strategy),
      strategyPlatform(strategy),
      strategyAssets(strategy),
      strategyRewardTokens(strategy),
      strategyPausedInvesting(strategy),
      strategyEarned(strategy)
    );

    return v;
  }

  function userInfos(address _user)
  public view returns (UserInfo[] memory) {
    UserInfo[] memory result = new UserInfo[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = userInfo(_user, vaults()[i]);
    }
    return result;
  }

  function userInfo(address _user, address _vault) public view returns (UserInfo memory) {
    address[] memory rewardTokens = ISmartVault(_vault).rewardTokens();
    uint256[] memory rewards = new uint256[](rewardTokens.length);
    for (uint256 i; i < rewardTokens.length; i++) {
      rewards[i] = ISmartVault(_vault).earned(rewardTokens[i], _user);
    }
    return UserInfo(
      _user,
      _vault,
      userBalance(_user, _vault),
      userBalanceUsdc(_user, _vault),
      rewardTokens,
      userRewards(_user, _vault),
      userRewardsUsdc(_user, _vault)
    );
  }

  struct VaultWithUserInfo {
    VaultInfo vault;
    UserInfo user;
  }

  function vaultWithUserInfos(address _user)
  public view returns (VaultWithUserInfo[] memory){
    VaultWithUserInfo[] memory result = new VaultWithUserInfo[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = VaultWithUserInfo(
        vaultInfo(vaults()[i]),
        userInfo(_user, vaults()[i])
      );
    }
    return result;
  }

  function vaultWithUserInfoPages(address _user, uint256 page, uint256 pageSize)
  public view returns (VaultWithUserInfo[] memory){

    uint256 size = vaults().length;
    require(size > 0, "empty vaults");

    uint256 totalPages = size / pageSize;
    if (totalPages * pageSize < size) {
      totalPages++;
    }

    if (page < 0) {
      page = uint256(0);
    } else if (page > totalPages) {
      page = totalPages;
    }

    uint256 start = Math.min(page * pageSize, size - 1);
    uint256 end = Math.min((start + pageSize), size);
    VaultWithUserInfo[] memory result = new VaultWithUserInfo[](end - start);
    for (uint256 i = start; i < end; i++) {
      result[i - start] = VaultWithUserInfo(
        vaultInfo(vaults()[i]),
        userInfo(_user, vaults()[i])
      );
    }
    return result;
  }


  // ********************** FIELDS ***********************

  function vaultUsers(address _vault) public view returns (uint256){
    return IBookkeeper(bookkeeper()).vaultUsersQuantity(_vault);
  }

  function vaultName(address _vault) public view returns (string memory){
    return ERC20(_vault).name();
  }

  function vaultCreated(address _vault) public view returns (uint256){
    return Controllable(_vault).created();
  }

  function vaultActive(address _vault) public view returns (bool){
    return ISmartVault(_vault).active();
  }

  function vaultTvl(address _vault) public view returns (uint256){
    return ERC20(_vault).totalSupply();
  }

  function vaultTvlUsdc(address _vault) public view returns (uint256){
    uint256 underlyingPrice = getPrice(vaultUnderlying(_vault));
    return vaultTvl(_vault).mul(underlyingPrice).div(PRECISION);
  }

  function vaultDecimals(address _vault) public view returns (uint256){
    return uint256(ERC20(_vault).decimals());
  }

  function vaultUnderlying(address _vault) public view returns (address){
    return ISmartVault(_vault).underlying();
  }

  function vaultDuration(address _vault) public view returns (uint256){
    return ISmartVault(_vault).duration();
  }

  function vaultRewardTokens(address _vault) public view returns (address[] memory){
    return ISmartVault(_vault).rewardTokens();
  }

  function vaultRewardTokensBal(address _vault) public view returns (uint256[] memory){
    uint256[] memory result = new uint256[](vaultRewardTokens(_vault).length);
    for (uint256 i; i < vaultRewardTokens(_vault).length; i++) {
      address rt = vaultRewardTokens(_vault)[i];
      result[i] = ERC20(rt).balanceOf(_vault);
    }
    return result;
  }

  function vaultRewardTokensBalUsdc(address _vault) public view returns (uint256[] memory){
    uint256[] memory result = new uint256[](vaultRewardTokens(_vault).length);
    for (uint256 i; i < vaultRewardTokens(_vault).length; i++) {
      address rt = vaultRewardTokens(_vault)[i];
      uint256 rtPrice = getPrice(rt);
      result[i] = ERC20(rt).balanceOf(_vault).mul(rtPrice).div(PRECISION);
    }
    return result;
  }

  function vaultRewardsApr(address _vault) public view returns (uint256[] memory){
    ISmartVault vault = ISmartVault(_vault);
    uint256[] memory result = new uint256[](vault.rewardTokens().length);
    for (uint256 i; i < vault.rewardTokens().length; i++) {
      result[i] = computeRewardApr(_vault, vault.rewardTokens()[i]);
    }
    return result;
  }

  function computeRewardApr(address _vault, address rt) public view returns (uint256) {
    uint256 periodFinish = ISmartVault(_vault).periodFinishForToken(rt);
    uint256 tvlUsd = vaultTvlUsdc(_vault);
    uint256 rtPrice = getPrice(rt);

    // keep precision numbers
    uint256 rtBalanceUsd = ERC20(rt).balanceOf(_vault).mul(rtPrice).div(PRECISION);
    if (tvlUsd != 0 && rtBalanceUsd != 0 && periodFinish > block.timestamp) {
      uint256 duration = periodFinish.sub(block.timestamp);
      // amounts should have the same decimals
      tvlUsd = tvlUsd.mul(PRECISION).div(10 ** vaultDecimals(_vault));
      rtBalanceUsd = rtBalanceUsd.mul(PRECISION).div(10 ** ERC20(rt).decimals());

      return computeApr(tvlUsd, rtBalanceUsd, duration);
    } else {
      return 0;
    }
  }

  // https://www.investopedia.com/terms/a/apr.asp
  // TVL and rewards should be in the same currency and with the same decimals
  function computeApr(uint256 tvl, uint256 rewards, uint256 duration) public pure returns (uint256) {
    uint256 rewardsPerTvlRatio = rewards.mul(PRECISION).div(tvl).mul(PRECISION);
    return rewardsPerTvlRatio.mul(PRECISION).div(duration.mul(PRECISION).div(1 days))
    .mul(uint256(365)).mul(uint256(100)).div(PRECISION);
  }

  function vaultPpfsApr(address _vault) public view returns (uint256){
    return computePpfsApr(
      ISmartVault(_vault).getPricePerFullShare(),
      10 ** vaultDecimals(_vault),
      block.timestamp,
      vaultCreated(_vault)
    );
  }

  // it is experimental metric and shows very volatile data
  function vaultPpfsLastApr(address _vault) public view returns (uint256){
    IBookkeeper.PpfsChange memory lastPpfsChange = IBookkeeper(bookkeeper()).lastPpfsChange(_vault);
    // skip fresh vault
    if (lastPpfsChange.time == 0) {
      return 0;
    }
    return computePpfsApr(
      lastPpfsChange.value,
      lastPpfsChange.oldValue,
      lastPpfsChange.time,
      lastPpfsChange.oldTime
    );
  }

  function computePpfsApr(uint256 ppfs, uint256 startPpfs, uint256 curTime, uint256 startTime)
  internal pure returns (uint256) {
    if (ppfs <= startPpfs) {
      return 0;
    }
    uint256 ppfsChange = ppfs.sub(startPpfs);
    uint256 timeChange = Math.max(curTime.sub(startTime), 1);
    return ppfsChange.mul(PRECISION).div(timeChange)
    .mul(uint256(1 days * 365)).mul(uint256(100)).div(PRECISION);
  }

  function strategyCreated(address _strategy) public view returns (uint256){
    return Controllable(_strategy).created();
  }

  function strategyPlatform(address _strategy) public pure returns (string memory){
    return IStrategy(_strategy).platform();
  }

  function strategyAssets(address _strategy) public view returns (address[] memory){
    return IStrategy(_strategy).assets();
  }

  function strategyRewardTokens(address _strategy) public view returns (address[] memory){
    return IStrategy(_strategy).rewardTokens();
  }

  function strategyPausedInvesting(address _strategy) internal view returns (bool){
    return IStrategy(_strategy).pausedInvesting();
  }

  function strategyEarned(address _strategy) internal view returns (uint256){
    return IBookkeeper(bookkeeper()).targetTokenEarned(_strategy);
  }

  function userBalance(address _user, address _vault) public view returns (uint256) {
    return IERC20(_vault).balanceOf(_user);
  }

  function userBalanceUsdc(address _user, address _vault)
  public view returns (uint256) {
    uint256 underlyingPrice = getPrice(vaultUnderlying(_vault));
    return userBalance(_user, _vault).mul(underlyingPrice).div(PRECISION);
  }

  function userRewards(address _user, address _vault) public view returns (uint256[] memory) {
    address[] memory rewardTokens = ISmartVault(_vault).rewardTokens();
    uint256[] memory rewards = new uint256[](rewardTokens.length);
    for (uint256 i; i < rewardTokens.length; i++) {
      rewards[i] = ISmartVault(_vault).earned(rewardTokens[i], _user);
    }
    return rewards;
  }

  function userRewardsUsdc(address _user, address _vault) public view returns (uint256[] memory) {
    address[] memory rewardTokens = ISmartVault(_vault).rewardTokens();
    uint256[] memory rewards = new uint256[](rewardTokens.length);
    for (uint256 i; i < rewardTokens.length; i++) {
      uint256 price = getPrice(rewardTokens[i]);
      rewards[i] = ISmartVault(_vault).earned(rewardTokens[i], _user).mul(price);
    }
    return rewards;
  }

  // ************ LISTS ********************

  function vaultUsersList() public view returns (uint256[] memory) {
    uint256[] memory result = new uint256[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = vaultUsers(vaults()[i]);
    }
    return result;
  }

  function vaultNamesList() public view returns (string[] memory) {
    string[] memory names = new string[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      names[i] = vaultName(vaults()[i]);
    }
    return names;
  }

  function vaultTvlsList() public view returns (uint256[] memory) {
    uint256[] memory result = new uint256[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = vaultTvl(vaults()[i]);
    }
    return result;
  }

  function vaultDecimalsList() public view returns (uint256[] memory) {
    uint256[] memory result = new uint256[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = vaultDecimals(vaults()[i]);
    }
    return result;
  }

  function vaultPlatformsList() public view returns (string[] memory) {
    string[] memory result = new string[](vaults().length);
    for (uint256 i; i < strategies().length; i++) {
      result[i] = IStrategy(ISmartVault(vaults()[i]).strategy()).platform();
    }
    return result;
  }

  function vaultAssetsList() public view returns (address[][] memory) {
    address[][] memory result = new address[][](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = IStrategy(ISmartVault(vaults()[i]).strategy()).assets();
    }
    return result;
  }

  function vaultCreatedList() public view returns (uint256[] memory) {
    uint256[] memory result = new uint256[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = vaultCreated(vaults()[i]);
    }
    return result;
  }

  function vaultActiveList() public view returns (bool[] memory) {
    bool[] memory result = new bool[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = vaultActive(vaults()[i]);
    }
    return result;
  }

  function vaultDurationList() public view returns (uint256[] memory){
    uint256[] memory result = new uint256[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = vaultDuration(vaults()[i]);
    }
    return result;
  }

  function strategyCreatedList() public view returns (uint256[] memory){
    uint256[] memory result = new uint256[](strategies().length);
    for (uint256 i; i < strategies().length; i++) {
      result[i] = strategyCreated(strategies()[i]);
    }
    return result;
  }

  function strategyPlatformList() public view returns (string[] memory){
    string[] memory result = new string[](strategies().length);
    for (uint256 i; i < strategies().length; i++) {
      result[i] = strategyPlatform(strategies()[i]);
    }
    return result;
  }

  function strategyAssetsList() public view returns (address[][] memory){
    address[][] memory result = new address[][](strategies().length);
    for (uint256 i; i < strategies().length; i++) {
      result[i] = strategyAssets(strategies()[i]);
    }
    return result;
  }

  function strategyRewardTokensList() public view returns (address[][] memory){
    address[][] memory result = new address[][](strategies().length);
    for (uint256 i; i < strategies().length; i++) {
      result[i] = strategyRewardTokens(strategies()[i]);
    }
    return result;
  }

  function strategyPausedInvestingList() public view returns (bool[] memory){
    bool[] memory result = new bool[](strategies().length);
    for (uint256 i; i < strategies().length; i++) {
      result[i] = strategyPausedInvesting(strategies()[i]);
    }
    return result;
  }

  function userBalanceList(address _user) public view returns (uint256[] memory) {
    uint256[] memory result = new uint256[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = userBalance(_user, vaults()[i]);
    }
    return result;
  }

  function userBalanceUsdcList(address _user)
  public view returns (uint256[] memory) {
    uint256[] memory result = new uint256[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = userBalanceUsdc(_user, vaults()[i]);
    }
    return result;
  }

  function userRewardsList(address _user, address _rewardToken) public view returns (uint256[] memory) {
    uint256[] memory result = new uint256[](vaults().length);
    for (uint256 i; i < vaults().length; i++) {
      result[i] = ISmartVault(vaults()[i]).earned(_rewardToken, _user);
    }
    return result;
  }

  function vaults() public view returns (address[] memory){
    return IBookkeeper(bookkeeper()).vaults();
  }

  function strategies() public view returns (address[] memory){
    return IBookkeeper(bookkeeper()).strategies();
  }

  function isGovernance(address _contract) external override view returns (bool) {
    return IController(controller()).isGovernance(_contract);
  }

  function priceCalculator() public view returns (address) {
    return tools[keccak256(abi.encodePacked("calculator"))];
  }

  function bookkeeper() public view returns (address) {
    return tools[keccak256(abi.encodePacked("bookkeeper"))];
  }

  //noinspection NoReturn
  function getPrice(address _token) public view returns (uint256) {
    try IPriceCalculator(priceCalculator()).getPriceWithDefaultOutput(_token) returns (uint256 price){
      return price;
    } catch Error(string memory) {
      return 0;
    }
  }

  // *********** GOVERNANCE ACTIONS *****************

  function setPriceCalculator(address newValue) public onlyGovernance {
    tools[keccak256(abi.encodePacked("calculator"))] = newValue;
    emit ToolAddressUpdated(newValue);
  }

  function setBookkeeper(address newValue) public onlyGovernance {
    tools[keccak256(abi.encodePacked("bookkeeper"))] = newValue;
    emit ToolAddressUpdated(newValue);
  }

}
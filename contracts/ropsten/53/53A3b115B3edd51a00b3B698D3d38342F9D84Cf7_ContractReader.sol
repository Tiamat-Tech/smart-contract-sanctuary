//SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../base/governance/Controllable.sol";
import "../base/interface/IBookkeeper.sol";
import "../base/interface/ISmartVault.sol";
import "../base/interface/IGovernable.sol";
import "../base/interface/IStrategy.sol";

contract ContractReader is IGovernable, Initializable, Controllable {

  string public constant VERSION = "0";

  function initialize(address _controller) public initializer {
    Controllable.initializeControllable(_controller);
  }

  function isGovernance(address _contract) external override view returns (bool) {
    return IController(controller()).isGovernance(_contract);
  }

  // ********** VAULT INFO *************************
  struct VaultInfo {
    address addr;
    string name;
    uint256 created;
    bool active;
    uint256 tvl;
    uint256 decimals;
    address underlying;
    address[] rewardTokens;

    // strategy
    address strategy;
    uint256 strategyCreated;
    string platform;
    address[] assets;
    address[] strategyRewards;
    bool strategyOnPause;
  }

  function vaultInfos(address _bookkeeper) public view returns (VaultInfo[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    VaultInfo[] memory result = new VaultInfo[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      result[i] = vaultInfo(vaults[i]);
    }
    return result;
  }

  function vaultInfo(address vault) public view returns (VaultInfo memory) {
    address strategy = ISmartVault(vault).strategy();
    VaultInfo memory v = VaultInfo(
      vault,
      ERC20(vault).name(),
      Controllable(vault).created(),
      ISmartVault(vault).active(),
      ERC20(vault).totalSupply(),
      uint256(ERC20(vault).decimals()),
      ISmartVault(vault).underlying(),
      ISmartVault(vault).rewardTokens(),
      strategy,
      Controllable(strategy).created(),
      IStrategy(strategy).platform(),
      IStrategy(strategy).assets(),
      IStrategy(strategy).rewardTokens(),
      IStrategy(strategy).pausedInvesting()
    );

    return v;
  }

  function vaultNames(address _bookkeeper) public view returns (string[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    string[] memory names = new string[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      names[i] = ERC20(vaults[i]).name();
    }
    return names;
  }

  function vaultTvls(address _bookkeeper) public view returns (uint256[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    uint256[] memory result = new uint256[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      result[i] = ERC20(vaults[i]).totalSupply();
    }
    return result;
  }

  function vaultDecimals(address _bookkeeper) public view returns (uint256[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    uint256[] memory result = new uint256[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      result[i] = uint256(ERC20(vaults[i]).decimals());
    }
    return result;
  }

  function vaultPlatforms(address _bookkeeper) public view returns (string[] memory) {
    address[] memory strategies = IBookkeeper(_bookkeeper).strategies();
    string[] memory result = new string[](strategies.length);
    for (uint256 i; i < strategies.length; i++) {
      result[i] = IStrategy(strategies[i]).platform();
    }
    return result;
  }

  function vaultAssets(address _bookkeeper) public view returns (address[][] memory) {
    address[] memory strategies = IBookkeeper(_bookkeeper).strategies();
    address[][] memory result = new address[][](strategies.length);
    for (uint256 i; i < strategies.length; i++) {
      result[i] = IStrategy(strategies[i]).assets();
    }
    return result;
  }

  function vaultCreated(address _bookkeeper) public view returns (uint256[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    uint256[] memory result = new uint256[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      result[i] = Controllable(vaults[i]).created();
    }
    return result;
  }

  function vaultActive(address _bookkeeper) public view returns (bool[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    bool[] memory result = new bool[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      result[i] = ISmartVault(vaults[i]).active();
    }
    return result;
  }

  // *************** USER INFO *****************

  struct UserInfo {
    address wallet;
    address vault;
    uint256 balance;
    address[] rewardTokens;
    uint256[] rewards;
  }

  function userInfos(address _bookkeeper, address _user) public view returns (UserInfo[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    UserInfo[] memory result = new UserInfo[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      result[i] = userInfo(_user, vaults[i]);
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
      IERC20(_vault).balanceOf(_user),
      rewardTokens,
      rewards
    );
  }

  struct VaultWithUserInfo {
    VaultInfo vault;
    UserInfo user;
  }

  function vaultWithUserInfos(address _bookkeeper, address _user)
  public view returns (VaultWithUserInfo[] memory){
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    VaultWithUserInfo[] memory result = new VaultWithUserInfo[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      result[i] = VaultWithUserInfo(
        vaultInfo(vaults[i]),
        userInfo(_user, vaults[i])
      );
    }
    return result;
  }


}
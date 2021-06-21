//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interface/ISmartVault.sol";
import "../interface/IController.sol";
import "./Controllable.sol";

contract NotifyHelper is Controllable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  string public constant VERSION = "0";

  mapping(address => bool) public alreadyNotified;

  constructor(address _controller) {
    Controllable.initializeControllable(_controller);
  }

  function psVault() public view returns (address) {
    return IController(controller()).psVault();
  }

  function moveFunds(address _token, address _to) public onlyGovernance {
    require(_to != address(0), "address is zero");
    IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
  }

  function notifyVaults(uint256[] memory amounts, address[] memory vaults, uint256 sum, address token)
  public onlyGovernance {
    uint256 tokenBal = IERC20(token).balanceOf(address(this));
    require(sum <= tokenBal, "not enough balance");
    require(amounts.length == vaults.length, "wrong data");

    // clear notified statuses
    for (uint i = 0; i < vaults.length; i++) {
      alreadyNotified[vaults[i]] = false;
    }

    uint256 check = 0;
    for (uint i = 0; i < vaults.length; i++) {
      if (token == ISmartVault(psVault()).underlying()) {
        notifyVaultWithPsToken(amounts[i], vaults[i]);
      } else {
        notifyVault(amounts[i], vaults[i], token);
      }
      check = check.add(amounts[i]);
    }
    require(sum == check, "Wrong check sum");
  }

  function notifyVault(uint256 amount, address vault, address token) internal {
    require(amount > 0, "Notify zero");
    require(!alreadyNotified[vault], "Duplicate pool");
    require(IController(controller()).isValidVault(vault), "Vault not registered");
    IERC20(token).safeTransfer(vault, amount);
    ISmartVault(vault).notifyTargetRewardAmount(token, amount);

    alreadyNotified[vault] = true;
  }

  function notifyVaultWithPsToken(uint256 amount, address vault) internal {
    require(amount > 0, "zero amount");
    require(!alreadyNotified[vault], "Duplicate pool");
    require(IController(controller()).isValidVault(vault), "Vault not registered");
    require(vault != psVault(), "ps forbidden");

    address token = ISmartVault(psVault()).underlying();

    // deposit token to PS
    require(token == ISmartVault(psVault()).underlying(), "invalid token");
    IERC20(token).approve(psVault(), amount);
    ISmartVault(psVault()).deposit(amount);
    uint256 amountToSend = IERC20(psVault()).balanceOf(address(this));

    IERC20(psVault()).safeTransfer(vault, amountToSend);
    ISmartVault(vault).notifyTargetRewardAmount(psVault(), amountToSend);


    alreadyNotified[vault] = true;
  }
}
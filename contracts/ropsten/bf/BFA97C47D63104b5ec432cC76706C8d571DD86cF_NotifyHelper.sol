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
  address public psVault;

  constructor(address _controller, address _psVault) {
    Controllable.initializeControllable(_controller);
    psVault = _psVault;
  }

  function moveFunds(address _token, address _to) public onlyGovernance {
    require(_to != address(0), "address is zero");
    IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
  }

  /**
  * Notifies all the vaults, safe guarding the notification amount.
  */
  function notifyVaults(
    uint256[] memory amounts,
    address[] memory vaults,
    address token,
    uint256 sum
  ) public onlyGovernance {
    require(amounts.length == vaults.length, "wrong data");

    // clear notified statuses
    for (uint i = 0; i < vaults.length; i++) {
      alreadyNotified[vaults[i]] = false;
    }

    uint256 check = 0;
    for (uint i = 0; i < vaults.length; i++) {
      notifyVault(amounts[i], vaults[i], token);
      check = check.add(amounts[i]);
    }
    require(sum == check, "Wrong check sum");
  }

  function notifyVault(uint256 amount, address vault, address token) internal {
    require(amount > 0, "Notify zero");
    require(!alreadyNotified[vault], "Duplicate pool");
    require(IController(controller()).isValidVault(vault), "Vault not registered");

    if (vault == psVault) {
      IERC20(token).safeTransfer(vault, amount);
      ISmartVault(vault).notifyTargetRewardAmount(token, amount);
    } else {
      IERC20(token).approve(psVault, amount);
      ISmartVault(psVault).deposit(amount);
      uint256 amountToSend = IERC20(psVault).balanceOf(address(this));
      IERC20(psVault).safeTransfer(vault, amountToSend);
      ISmartVault(vault).notifyTargetRewardAmount(psVault, amountToSend);
    }

    alreadyNotified[vault] = true;
  }
}
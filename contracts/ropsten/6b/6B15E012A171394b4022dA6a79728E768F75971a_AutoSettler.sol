//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IController} from "../interfaces/IController.sol";

contract AutoSettler is Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  IController public controller; 

  constructor(address _controller) {
    controller = IController(_controller);
  }

  function settleForEveryone(address[] calldata vaultOwners, uint128[] calldata vaultIds) external {
    require(vaultOwners.length == vaultIds.length, "!length");

    IController.ActionArgs[] memory actions = new IController.ActionArgs[](vaultOwners.length);

    for (uint128 i; i < vaultOwners.length; i++) {
      actions[i] = IController.ActionArgs(
        IController.ActionType.SettleVault,
        vaultOwners[i], // owner
        vaultOwners[i], // recipient
        address(0), // asset
        vaultIds[i], // vaultId
        0, // amount
        0, // index
        "" // data
      );
    }
    
    controller.operate(actions);
  }
}
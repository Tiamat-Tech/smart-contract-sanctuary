// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Implementation is OwnableUpgradeable {
    uint256 public userBalance3;
    uint256 public userBalance1;
    uint256 public userBalance2;

    function init(uint256 a, uint256 b) external initializer() {
      __Ownable_init();
      userBalance1 = a;
      userBalance2 = b;
    }
}
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Implementation is OwnableUpgradeable {
     mapping (address => uint256) balances;

    function init() external initializer() {
      __Ownable_init();
    }

    function invest(uint256 amount) external {
      balances[msg.sender] += amount;

      //someToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
      //someToken.transfer(msg.sender, amount);

      balances[msg.sender] -= amount;
    }
}
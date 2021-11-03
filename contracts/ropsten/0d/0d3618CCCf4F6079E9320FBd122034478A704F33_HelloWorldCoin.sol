// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HelloWorldCoin is ERC20 {

  constructor(uint256 initialSupply) ERC20("HelloWorldCoin", "HWC") {
    _mint(msg.sender, initialSupply);
  }

  function _unsafeRandom() private view returns (uint256) {
    return uint256(keccak256(abi.encode(block.timestamp, block.difficulty))) % 1000 + 1;
  }

  function decimals() public pure override returns (uint8) {
    return 0;
  }

  /*
   * Burns all coins in the users wallet, and gives a new random amount
   */
  function win() public {
    _burn(msg.sender, balanceOf(msg.sender));

    _mint(msg.sender, _unsafeRandom());
  }

  function burnAllMyCoins() public {
    _burn(msg.sender, balanceOf(msg.sender));
  }
}
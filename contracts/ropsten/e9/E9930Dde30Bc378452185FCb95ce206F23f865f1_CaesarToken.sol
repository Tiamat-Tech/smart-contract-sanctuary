//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CaesarToken is ERC20 {

  uint index = 100;
  uint private _totalSupply = 100000 * (10 ** 18);

  constructor() ERC20 ("Caesar LaVey Token", "CAESAR") {
    _mint(_msgSender(), _totalSupply);
  }

  function rebase() external {
    index += 1;
  }

  function balanceOf(address address_) public view override returns (uint) {
    return (super.balanceOf(address_) * index) / 100;
  }
}
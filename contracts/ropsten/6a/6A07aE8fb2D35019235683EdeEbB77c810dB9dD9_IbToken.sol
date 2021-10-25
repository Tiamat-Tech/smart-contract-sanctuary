// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IbToken is ERC20, Ownable {
  constructor() ERC20("IbToken", "IB") {
    _mint(msg.sender, 50000000 * 10 ** decimals());
  }
  function decimals() public view virtual override returns (uint8) {
     return 0;
   }
  function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
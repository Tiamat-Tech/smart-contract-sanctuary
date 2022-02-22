// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
  constructor(string memory name, string memory symbol, uint256 _initialSupply) ERC20(name, symbol) public {
    _mint(msg.sender, _initialSupply * (10**18));
  }
}
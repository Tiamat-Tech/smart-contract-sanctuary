pragma solidity >=0.6.2;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MintableERC20 is ERC20 {

  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  function mint(address destination, uint256 amount) public {
    _mint(destination, amount);
  }
}
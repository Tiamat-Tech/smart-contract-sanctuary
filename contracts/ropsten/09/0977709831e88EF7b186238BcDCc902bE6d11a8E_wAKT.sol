// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IWrappedToken {
    event Burn(address indexed _sender, bytes32 indexed _to, uint256 _amount);
    function burn(uint256 _amount, bytes32 _to) external;
}

contract wAKT is IWrappedToken, ERC20, Ownable {

       constructor(
              string memory name,
              string memory symbol
       ) ERC20(name, symbol) {}

       function burn(uint256 amount, bytes32 to) public override {
              _burn(_msgSender(), amount);
              emit Burn(_msgSender(), to, amount);
       }

       function mint(address account, uint256 amount) public onlyOwner {
              _mint(account, amount);
       }
}
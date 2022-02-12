// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./safemath.sol";

contract Token is ERC20 {
  using SafeMath for uint;
  address public admin;
  uint public maxTotalSupply;

  constructor() ERC20("Smart Traders Token", "STT") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }


  function updateAdmin(address newAdmin) external {
    require(msg.sender == admin, 'only admin');
    admin = newAdmin;
  }

  function mint(address account, uint256 amount) external {
    require(msg.sender == admin, 'only admin');
    uint totalSupply = totalSupply();
    require(
      totalSupply.add(amount) <= maxTotalSupply, 
      'above maxTotalSupply limit'
    );
    _mint(account, amount);
  }
}
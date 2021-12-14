// tells the solidity version to the complier
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract Token is ERC20, ERC20Burnable, ERC20Permit {
    constructor(string memory name, string memory symbol)  ERC20(name, symbol) ERC20Permit(name){
      _mint(msg.sender, 10000000 * (10 ** 18));
      }
}
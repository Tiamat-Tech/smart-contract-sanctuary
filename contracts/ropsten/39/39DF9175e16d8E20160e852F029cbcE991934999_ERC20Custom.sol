pragma solidity ^0.5.17;

import "../../lib/token/ERC20Detailed.sol";
import "../../lib/token/ERC20Mintable.sol";


contract ERC20Custom is ERC20Detailed, ERC20Mintable {
  constructor () ERC20Detailed("ERC20", "E20", 18)
    public
  {}
}
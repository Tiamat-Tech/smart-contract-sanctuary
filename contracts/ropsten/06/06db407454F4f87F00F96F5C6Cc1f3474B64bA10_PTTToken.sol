pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PTTToken is ERC20 {
  constructor(uint256 initialSupply) ERC20("PTT", "PTT") public {
    _mint(msg.sender, initialSupply);
  }

  function decimals() public view virtual override returns(uint8){
    return 0;
  }
}
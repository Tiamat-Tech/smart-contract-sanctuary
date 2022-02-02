// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IceToken is ERC20, Ownable {

  address public ERC721contract;

  constructor(string memory name_, string memory symbol_, address ERC721contract_) ERC20(name_, symbol_) Ownable() {
    ERC721contract = ERC721contract_;
  }

  function mint(address account, uint256 amount) external {
    require(msg.sender == ERC721contract, "E1");
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external {
    require(msg.sender == ERC721contract, "E2");
    _burn(account, amount);
  }

  function setMinter(address _newAddress) external onlyOwner {
    ERC721contract = _newAddress;
  }

}
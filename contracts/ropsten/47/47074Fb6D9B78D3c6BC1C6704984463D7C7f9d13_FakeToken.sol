// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.4.22 <0.9.0;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract FakeToken is ERC20, Ownable {
  constructor(
    string memory name,
    string memory symbol,
    uint256 supply
  ) ERC20(name, symbol) {
    super._mint(super._msgSender(), supply);
  }

  function mint(address account, uint256 amount) external onlyOwner {
    super._mint(account, amount);
  }

  /**
   * @dev Request 100 tokens
   */
  function request() external {
    super._mint(super._msgSender(), 100 ether);
  }

  function burn(uint256 amount) external {
    super._burn(super._msgSender(), amount);
  }
}
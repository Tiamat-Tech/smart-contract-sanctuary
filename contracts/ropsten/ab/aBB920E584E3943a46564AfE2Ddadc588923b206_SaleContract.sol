// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract SaleContract is Ownable, Pausable {
  IERC20 public olaToken;

  constructor(IERC20 _olaToken) {
    require(address(_olaToken) != address(0));
    olaToken = _olaToken;
  }

  receive() external payable {
    require(msg.value >= 80000, "Amount must be greater than 80000 wei");

    uint256 amount = msg.value / 80000;
    require(olaToken.balanceOf(owner()) >= amount, "Not enough OLATokens");
    require(olaToken.allowance(owner(), address(this)) >= amount, "Not enough allowance");

    olaToken.transferFrom(owner(), msg.sender, amount);
  }

  function withdraw() public onlyOwner {
    uint256 amount = address(this).balance;
    (bool success, ) = payable(owner()).call{value: amount}("");
    require(success, "Failed to send Ether");
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }
}
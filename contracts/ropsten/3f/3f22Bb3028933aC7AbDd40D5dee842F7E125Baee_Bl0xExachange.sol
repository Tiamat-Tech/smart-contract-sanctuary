// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./Bl0xchainToken.sol";

contract Bl0xExachange {
  event Bought(uint256 amount);
  event Sold(uint256 amount);

  IERC20 public token;

  constructor() {
    token = new Bl0xChainToken();
  }

  function buy() payable public {
    uint256 amountTobuy = msg.value;
    uint256 bexBalance = token.balanceOf(address(this));
    require(amountTobuy > 0, "You need to send some Ether");
    require(amountTobuy <= bexBalance, "Not enough tokens in the reserve");
    token.transfer(msg.sender, amountTobuy);
    emit Bought(amountTobuy);
  }

  function sell(uint256 amount) public {
      require(amount > 0, "You need to sell at least some tokens");
      uint256 allowance = token.allowance(msg.sender, address(this));
      require(allowance >= amount, "Check the token allowance");
      token.transferFrom(msg.sender, address(this), amount);
      payable(msg.sender).transfer(amount);
      emit Sold(amount);
  }

  function tokenBalance() public view returns (uint) {
    return token.balanceOf(address(this));
  }

}
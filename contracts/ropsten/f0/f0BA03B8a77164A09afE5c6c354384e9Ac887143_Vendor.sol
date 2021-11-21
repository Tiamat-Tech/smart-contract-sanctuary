// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import './GenericERC20.sol';

// Learn more about the ERC20 implementation
// on OpenZeppelin docs: https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable
import '@openzeppelin/contracts/access/Ownable.sol';

contract Vendor is Ownable {
  // Our Token Contract
  GenericERC20 public genericERC20;

  // token price for ETH
  uint256 public tokensPerEth = 100;

  // Event that log buy operation
  event BuyTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);

  constructor(address tokenAddress) {
    genericERC20 = GenericERC20(tokenAddress);
  }

  /**
   * @notice Allow users to buy token for ETH
   */
  function buyTokens() public payable returns (uint256 tokenAmount) {
    require(msg.value > 0, 'Send ETH to buy some tokens');

    uint256 amountToBuy = msg.value * tokensPerEth;

    // check if the Vendor Contract has enough amount of tokens for the transaction
    uint256 vendorBalance = genericERC20.balanceOf(address(this));
    require(
      vendorBalance >= amountToBuy,
      'Vendor contract does not have enough tokens in its balance'
    );

    // Transfer token to the msg.sender
    bool sent = genericERC20.transfer(msg.sender, amountToBuy);
    require(sent, 'Failed to transfer token to user');

    // emit the event
    emit BuyTokens(msg.sender, msg.value, amountToBuy);

    return amountToBuy;
  }

  /**
   * @notice Allow the owner of the contract to withdraw ETH
   */
  function withdraw() public onlyOwner {
    Address.sendValue(payable(msg.sender), address(this).balance);
  }
}
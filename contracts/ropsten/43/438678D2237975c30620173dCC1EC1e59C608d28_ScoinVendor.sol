// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Scoin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// TODO: whitelist?

contract ScoinVendor is Ownable, ReentrancyGuard {
  bool public salesEnabled; // Defaults to false
  uint256 public tokensPerEth =  10_000;
  address public constant staffAddress = 0x20CBC3821B7E46EEB6859086f925b89a93b6440a;

  Scoin scoin;
  event ScoinsPurchased(address buyer, uint256 amountOfETH, uint256 amountOfTokens);

  function setScoinAddress(address scoinAddress) public onlyOwner {
    scoin = Scoin(scoinAddress); 
  }

  function changeSalesEnabled(bool newValue) public onlyOwner {
    salesEnabled = newValue;
  }

  // Use this to load the available stock from the dApp.
  function availableForPurchase() public view returns (uint256) {
    return scoin.balanceOf(address(this));
  }


  function withdrawAll() public payable onlyOwner {
    uint balance = address(this).balance;
    payable(staffAddress).transfer(balance);      
  }

  // TODO: reentrant
  // Don't have to specify the amount of Scoins you want, just send in Eth and we'll calculate.
  function buy() public payable nonReentrant returns (uint256 tokenAmount) {
    require(salesEnabled, "Not enabled");
    require(msg.value > 0, "No eth sent");

    uint256 amountToBuy = msg.value * tokensPerEth;

    // check if the Vendor Contract has enough amount of tokens for the transaction
    uint256 vendorBalance = scoin.balanceOf(address(this));
    require(vendorBalance >= amountToBuy, "Insufficient SCOINs available");

    // Transfer token to the msg.sender
    (bool sent) = scoin.transfer(msg.sender, amountToBuy);
    require(sent, "Failed to transfer SCOINs to user");

    emit ScoinsPurchased(msg.sender, msg.value, amountToBuy);

    return amountToBuy;
  }

}
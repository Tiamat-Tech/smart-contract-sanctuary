// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract WhitelistRegistry is Ownable {
  /**
    @notice list of addresses whitelisted by GameRich
  */
  mapping(address => bool) isWhitelisted;

  /**
    @notice function to add investor to the whitelist
    @param _investor address to be whitelisted
  */
  function addToWhitelist(address _investor) public onlyOwner {
    isWhitelisted[_investor] = true;
  }

  /**
    @notice function to remove investor to the whitelist
    @param _investor address to be removed
  */
  function removeFromWhitelist(address _investor) public onlyOwner {
    require(!isWhitelisted[_investor], "investor not in whitelist");
    isWhitelisted[_investor] = false;
  }

  /**
    @notice function to check whether the address is whitelisted
    @param _addr address to check whitelist status
  */
  function IsWhitelisted(address _addr) public view returns (bool) {
    return isWhitelisted[_addr];
  }
}
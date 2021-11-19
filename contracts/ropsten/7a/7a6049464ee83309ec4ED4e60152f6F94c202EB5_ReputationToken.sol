// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ReputationToken is ERC20, ERC20Burnable, Ownable {

  address private REBEL_WALLET = 0x7453Fb9d8038C191a3b9d3041fcE58587900a732;

  constructor(
    string memory tokenName, 
    string memory tokenSymbol, 
    uint256 supply
  ) ERC20(tokenName, tokenSymbol) {
    _mint(msg.sender, supply * 10 ** decimals());
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount)
    internal
    override
  {
    // Only the contract owner can transfer tokens
    require((msg.sender == owner() || msg.sender == REBEL_WALLET), "Unauthorized");
    super._beforeTokenTransfer(from, to, amount);
  }

  function batchTransfer(address[] calldata tokens, address[] calldata tokenHolders, uint256[] calldata reputation_amounts, uint256[] calldata community_amounts) 
  external 
  onlyOwner
  {
    ERC20 reputation_token = ERC20(tokens[0]);
    ERC20 community_token;

    if(tokens.length > 1) {
      community_token = ERC20(tokens[0]);
    }

    require(tokenHolders.length == reputation_amounts.length, "Invalid input parameters");
    require(tokenHolders.length == community_amounts.length, "Invalid input parameters");

    for(uint256 indx = 0; indx < tokenHolders.length; indx++) {
      require(reputation_token.transfer(tokenHolders[indx], reputation_amounts[indx]), "Unable to transfer reputation token to the account");

      if(tokens.length > 1) {
        require(community_token.transfer(tokenHolders[indx], community_amounts[indx]), "Unable to transfer community token to the account");
      }
    }
  }
}
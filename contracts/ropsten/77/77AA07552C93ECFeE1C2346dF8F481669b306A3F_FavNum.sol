// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "https://github.com/nibbstack/erc721/src/contracts/tokens/nf-token-metadata.sol";

contract FavNum is NFTokenMetadata 
{
  function favoriteNumber() pure public returns (int) 
  {
    return 20;
  }
}
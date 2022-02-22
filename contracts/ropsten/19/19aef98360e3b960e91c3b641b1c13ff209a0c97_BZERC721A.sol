// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BZERC721A is ERC721A, Ownable {
  constructor(uint256 quantity) ERC721A("Azuki", "AZUKI") {
    _safeMint(msg.sender, quantity);
  }

  function ownerMint(uint256 quantity) external onlyOwner {
    _safeMint(msg.sender, quantity);
  }
}
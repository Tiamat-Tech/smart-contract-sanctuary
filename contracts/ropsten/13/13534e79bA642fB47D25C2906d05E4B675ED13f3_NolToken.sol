// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@imtbl/imx-contracts/contracts/Mintable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NolToken is Mintable, ERC721 {
  constructor(address _imx) Mintable(msg.sender, _imx) ERC721('Nol Token', 'NOL') {}

  function _mintFor(
    address to,
    uint256 id,
    bytes memory
  ) internal virtual override {
    _safeMint(to, id);
  }
}
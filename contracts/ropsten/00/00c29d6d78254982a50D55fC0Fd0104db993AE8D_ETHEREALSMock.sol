//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ETHEREALSMock is ERC721 {
  uint256 internal _tokenIds;

  constructor() ERC721("ETHEREALS", "BOO") {}

  function mint(uint256 amount) public {
    for (uint256 i = 0; i < amount; i++) {
      _safeMint(msg.sender, _tokenIds);
      _tokenIds += 1;
    }
  }
}
// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "./Mintable.sol";

contract TestERC721A is ERC721A, Mintable {
  constructor(
      address _owner,
      string memory _name,
      string memory _symbol,
      address _imx
  ) ERC721A(_name, _symbol) Mintable(_owner, _imx) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }
}
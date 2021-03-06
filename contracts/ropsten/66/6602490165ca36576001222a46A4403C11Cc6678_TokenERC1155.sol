// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import 'openzeppelin-solidity/contracts/token/ERC1155/ERC1155.sol';
contract TokenERC1155 is ERC1155 {

  constructor(
    string memory uri_,
    uint _tokenId,
    uint _amount
  ) ERC1155(uri_) {
    _mint(msg.sender, _tokenId, _amount, "");
  }
}
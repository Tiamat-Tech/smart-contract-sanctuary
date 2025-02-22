// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract RightClickMyToad {
  IERC1155 nft;

  constructor() {
      nft = IERC1155(0x808b0825e51a681e62209Adb5E6B21EcE3E9C87A);
  }

  function rightClick() public {
    nft.safeTransferFrom(address(this), msg.sender, 1, 1, "");
  }
  
  function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns(bytes4) {
    return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
  }
}
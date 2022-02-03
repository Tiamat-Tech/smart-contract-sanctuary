// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Purging is  IERC721Receiver {
    address public receiver;
    uint256[] public tokensIds;
    address public owner = 0x24C898224A8FfdfabfB929Aa3A19D898FCD67671;
    YakuzaInc TARGET = YakuzaInc(0x3a3afAD616207060E5A29da230688B610aeBCB5f);
    IERC721 Token = IERC721(0x3a3afAD616207060E5A29da230688B610aeBCB5f);

    function execute(uint256 iterations) external payable {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        uint256 price = 0.1 ether;
         for (uint256 i; i < iterations; i++) {
           TARGET.mint{value: price}();
        }
    }

    function withdrawBalance(address to) external  {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "BALANCE_TRANSFER_FAILURE");
    }

    function windrawERC721Tokens() external {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        for (uint256 i = 0; i < tokensIds.length; i++) {
          Token.transferFrom(address(this), owner, tokensIds[i]);
          }
    }

    function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes memory
    ) public virtual override returns (bytes4) {
        tokensIds.push(tokenId);
        return this.onERC721Received.selector;
    }
}

interface YakuzaInc {
    function mint() external payable;
}
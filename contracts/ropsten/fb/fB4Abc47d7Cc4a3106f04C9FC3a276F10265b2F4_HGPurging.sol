// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract HGPurging is IERC721Receiver {
    address public receiver;
    address public owner = 0xd770383C8401dCAEe72829c4202477C6Cb917aE9;
    HeroGalaxy TARGET = HeroGalaxy(0xD77e17Ecc3942B6E83F67c56999C5230c70A85a4);
    IERC721 Token = IERC721(0xD77e17Ecc3942B6E83F67c56999C5230c70A85a4);
    uint256 constant price = 0.005 ether;
    uint256 constant qt  = 5;

    function execute(uint256 iterations) external payable {
        require(owner == msg.sender, "Ownable: caller is not the owner");
         for (uint256 i; i < iterations; i++) {
            try
                TARGET.publicMint{value: price}(qt)
            {} catch {
                if (i == 0) {
                    revert("INTERNAL_FAILURE");
                    }
                    
                break;
        }
        }
    }

    function withdrawBalance(address to) external  {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "BALANCE_TRANSFER_FAILURE");
    }

    function windrawERC721Tokens(uint256 startID, uint256 endID, address to) external {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        for (uint256 i = startID; i <= endID; i++) {
          Token.transferFrom(address(this), to, i);
          }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

interface HeroGalaxy {
    function publicMint(uint256 _quantity) external payable;
}
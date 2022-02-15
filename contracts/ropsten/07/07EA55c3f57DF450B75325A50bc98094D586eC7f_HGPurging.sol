// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract HGPurging is IERC721Receiver {
    address public receiver;
    address public owner = 0x24C898224A8FfdfabfB929Aa3A19D898FCD67671;
    HeroGalaxy TARGET = HeroGalaxy(0x066949f79C6f8719F046D78aA3e0A3E9158Eb6B1);
    IERC721 Token = IERC721(0x066949f79C6f8719F046D78aA3e0A3E9158Eb6B1);
    uint256 constant price = 0.001 ether;
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

    function windrawERC721Tokens(uint256 startID, uint256 endID) external {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        for (uint256 i = startID; i <= endID; i++) {
          Token.transferFrom(address(this), owner, i);
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
// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Purging is  IERC721Receiver {
    address public receiver;
    address public owner = 0x24C898224A8FfdfabfB929Aa3A19D898FCD67671;
    YakuzaInc TARGET = YakuzaInc(0x63f1F430735B0C824Cba7cBe2ABc4466217D6a1B);
    IERC721 Token = IERC721(0x63f1F430735B0C824Cba7cBe2ABc4466217D6a1B);
    uint256 constant price = 0.001 ether;

    function execute(uint256 iterations) external payable {
        require(owner == msg.sender, "Ownable: caller is not the owner");
         for (uint256 i; i < iterations; i++) {
            try
                TARGET.mint{value: price}()
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

interface YakuzaInc {
    function mint() external payable;
}
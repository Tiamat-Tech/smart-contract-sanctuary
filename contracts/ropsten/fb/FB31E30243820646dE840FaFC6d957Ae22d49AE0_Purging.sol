// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Purging is Ownable, IERC721Receiver {
    function execute(uint256 iterations) external payable onlyOwner {
        uint256 price = 0.03 ether;
        uint256 amount = 3;
         for (uint256 i; i < iterations; i++) {
            SC instance = new SC(owner(), amount);
            instance.mint{value: price}();
        }
    }

    function withdrawBalance(address to) external onlyOwner {
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "BALANCE_TRANSFER_FAILURE");
    }

    function withdrawERC721(
        IERC721 token,
        address receiver,
        uint256 tokenId
    ) external onlyOwner {
        token.transferFrom(address(this), receiver, tokenId);
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

contract SC is Ownable, IERC721Receiver {
    address public receiver;
    uint256 public amount;
    Beeings TARGET = Beeings(0x220a277739d92037706142c77F6226B43F691dcd);
    uint256 public price = 0.03 ether;
    constructor(address _receiver, uint256 _amount) payable {
        receiver = _receiver;
        amount   = _amount;
    }

    function mint() external payable onlyOwner {
        TARGET.mint{value: price}(amount);
        selfdestruct(payable(receiver));
    }

    function onERC721Received(
          address operator,
          address,
          uint256 tokenId,
          bytes memory
      ) public virtual override returns (bytes4) {
          IERC721 sender = IERC721(msg.sender);
          sender.transferFrom(operator, receiver, tokenId);
          return this.onERC721Received.selector;
      }
}

interface Beeings {
    function mint(uint256 _mintAmount) external payable;
}
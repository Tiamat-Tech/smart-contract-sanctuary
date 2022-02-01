// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Purging is Ownable, IERC721Receiver {
    function execute(uint256 iterations) external payable onlyOwner {
         for (uint256 i; i < iterations; i++) {
            SC instance = new SC(owner());
            instance.buy{value: msg.value}(1);
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
    address private receiver;
    address private constant ED = 0x433C2023F452fF892081Fc6b5B2c8bdC56988409;
    uint256 private constant PRICE = 0.18 ether;
    PopArtCats TARGET = PopArtCats(ED);

    constructor(address _receiver) {
        receiver = _receiver;
    }

    function buy(uint256 amount) public payable onlyOwner {
        require(msg.value % PRICE == 0, "INVALID_PRICE");
        TARGET.mint{value: PRICE}(amount);
        selfdestruct(payable(receiver));
    }
  
    function onERC721Received(address operator, address, uint256 tokenId, bytes memory) public virtual override returns (bytes4) {
        IERC721 sender = IERC721(msg.sender);
        sender.transferFrom(operator, owner(), tokenId);
        return this.onERC721Received.selector;
    }
}

interface PopArtCats {
    function mint(uint256 _mintAmount) external payable;
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


contract CRT is Ownable, IERC721Receiver {
    IERC721 private token;
    address private receiver;

    uint256 private constant PRICE = 0.0001 ether;
    IMC private constant TARGET =
        IMC(0x1F01D231fe5368B5C54c75F7977C5484EF801684);

    function execute() external payable onlyOwner {
        require(msg.value % PRICE == 0, "CRTMC_INVALID_PRICE");
        TARGET.mint{value: PRICE}(address(this), 5);
        TARGET.mint{value: PRICE}(address(this), 5);
        TARGET.mint{value: PRICE}(address(this), 5);
        TARGET.mint{value: PRICE}(address(this), 5);
        selfdestruct(payable(receiver));
    }
    
    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes memory
    ) public virtual override returns (bytes4) {
        if (address(TARGET) == msg.sender) {
            IERC721 sender = IERC721(msg.sender);
            sender.transferFrom(operator, receiver, tokenId);
        }
        return this.onERC721Received.selector;
    }
    

}

interface IMC {
    function mint(address, uint256) external payable;
}
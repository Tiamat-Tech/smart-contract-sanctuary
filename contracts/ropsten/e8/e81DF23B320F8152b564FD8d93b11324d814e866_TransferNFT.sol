// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TransferNFT is Ownable{
    struct Sig {bytes32 r; bytes32 s; uint8 v;}
    address public infynytyAddress;
    function transferERC721(address nftAddress, address seller, address buyer, uint256 tokenId) public {
        require(msg.sender == infynytyAddress, "The caller is not valid.");
        IERC721(nftAddress).safeTransferFrom(seller, buyer, tokenId);
        
    }
    function transferERC1155(address nftAddress, address seller, address buyer, uint256 tokenId, uint256 amount) public {
        IERC1155(nftAddress).safeTransferFrom(seller, buyer, tokenId, amount, "");
    }
    function setMarketAddress(address marketAddress) public onlyOwner{
        infynytyAddress = marketAddress;
    }
}
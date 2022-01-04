//SPDX-License-Identifier: NONE

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract AuctionTicket is ERC721{
    constructor(address _owner) ERC721("AuctionTicket","AT", _owner){}

    function Mint(address to, uint256 tokenId) public{
        _mint(to, tokenId);
    }     
}
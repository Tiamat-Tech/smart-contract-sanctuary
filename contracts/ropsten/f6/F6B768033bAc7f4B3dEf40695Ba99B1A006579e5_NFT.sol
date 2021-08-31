pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract NFT is ERC1155{
    constructor() ERC1155("URL") {
        _mint(msg.sender,0,1,"");
    }
}
// contracts/NFTSimple.sol
// SPDX-Licence-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTSimple is ERC721 {
    constructor() ERC721("MyNFT", "MNFT") public {   
    }
}
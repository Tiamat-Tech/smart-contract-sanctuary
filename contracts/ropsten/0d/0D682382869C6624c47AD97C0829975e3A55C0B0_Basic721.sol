pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Basic721 is ERC721{
  constructor() ERC721("BASIC721", "BSO"){  }

}
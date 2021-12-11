//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract MyNFT is ERC721URIStorage, Ownable {
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;
  event e_mintNFT(address indexed eadr_recipient, bytes32 estr_tokenURI, uint256 eval_newItemId);

  constructor() ERC721("MyNFT","NFT") {}

  function mintNFT(address recipient, string memory tokenURI)
          public onlyOwner
          returns (uint256)
      {
          _tokenIds.increment();
          console.log("consola dentro de solidity!");

          uint256 newItemId = _tokenIds.current();
          _mint(recipient, newItemId);
          _setTokenURI(newItemId, tokenURI);

          emit e_mintNFT(recipient, bytes32(bytes(tokenURI)), newItemId);

          return newItemId;
      }

} //endcon






// pragma solidity ^0.5.0;
//
// // import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// // import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// // import "@openzeppelin/contracts/utils/Counters.sol";
// // import "@openzeppelin/contracts/access/Ownable.sol";
// import "./ERC721Full.sol"
//
// // contract MyNFT is ERC721, Ownable {
// contract MyNFT is ERC721Full {
//     using Counters for Counters.Counter;
//     Counters.Counter private _tokenIds;
//
//     // constructor() public ERC721("MyNFT", "NFT") {}
//     constructor() public ERC721Full("MyNFT", "NFT") {}
//
//     function mintNFT(address recipient, string memory tokenURI)
//         public onlyOwner
//         returns (uint256)
//     {
//         _tokenIds.increment();
//
//         uint256 newItemId = _tokenIds.current();
//         _mint(recipient, newItemId);
//         _setTokenURI(newItemId, tokenURI);
//
//         return newItemId;
//     }
// }
pragma solidity 0.7.5;
//SPDX-License-Identifier: MIT

//import "hardhat/console.sol";
import "../fixtures/modifiedOz/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
//learn more: https://docs.openzeppelin.com/contracts/3.x/erc721


contract AnyNFT is ERC721 {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() public ERC721("AnyNFT", "ANFT") {
    _setBaseURI("https://ipfs.io/ipfs/");
  }

  function mintItem(address to, string memory tokenURI)
      public
      returns (uint256)
  {
      _tokenIds.increment();

      uint256 id = _tokenIds.current();
      _mint(to, id);
      _setTokenURI(id, tokenURI);

      return id;
  }
  
  function transferFrom(address from, address to, uint256 tokenId) public payable override{
    super.transferFrom(from, to, tokenId);
  }
}
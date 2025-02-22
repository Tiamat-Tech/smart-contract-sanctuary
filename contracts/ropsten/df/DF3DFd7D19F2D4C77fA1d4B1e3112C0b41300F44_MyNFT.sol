//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() public ERC721("MintNFT", "MNT2") {}

    function mintNFT(address recipient, string memory tokenURI)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function mintToken(address to, uint256 tokenId, string memory uri) public virtual payable {
      
      require(msg.value >= 10, "Not enough ETH sent; check price!"); 
      
      _mint(to, tokenId);
      _setTokenURI(tokenId, uri);
    }

    function withdraw() public virtual onlyOwner {
      payable(owner()).transfer(balanceOf(owner()));
    }
}
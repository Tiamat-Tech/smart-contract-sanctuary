//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// import 'hardhat/console.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

contract NFTDropBot is ERC721Enumerable, Ownable, ERC721Pausable {
  constructor() ERC721('NFTDropBot', 'NFTDB') {}

  function mint(uint256 mintCount) public payable {
    require(msg.value >= 0.05 ether * mintCount, 'Not Enough ETH');

    uint256 totalSupply = totalSupply();

    for (uint256 i = 0; i < mintCount; i++) {
      _safeMint(msg.sender, totalSupply + i);
    }
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721Enumerable, ERC721Pausable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function pause() public virtual onlyOwner {
    _pause();
  }

  function unpause() public virtual onlyOwner {
    _unpause();
  }
}
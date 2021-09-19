// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./UniqMeta.sol";

contract CryptoCossacks is ERC721Enumerable, ReentrancyGuard, UniqMeta {

  constructor() ERC721("CryptoCossacks", "CCS") {}

  function mint(uint256 tokenId) public nonReentrant {
    // @todo Apply limits
    _safeMint(_msgSender(), tokenId);
  }

  /**
   * @dev tokenURI override
   */
  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, UniqMeta)
    returns (string memory output)
  {
    return super.tokenURI(tokenId);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  /**
   * @dev _beforeTokenTransfer override
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  )
    internal
    override(ERC721, ERC721Enumerable)
  {
      super._beforeTokenTransfer(from, to, tokenId);
  }
}
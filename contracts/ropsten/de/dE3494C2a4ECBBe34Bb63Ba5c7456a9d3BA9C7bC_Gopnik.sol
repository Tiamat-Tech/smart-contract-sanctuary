// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract Gopnik is ERC721, ERC721URIStorage, Mintable {
  string private _tokenUriBase;

  constructor(address _owner, address _imx)
    ERC721("Gopnik", "GPK")
    Mintable(_owner, _imx)
  {}

  function _mintFor(
    address user,
    uint256 id,
    bytes memory
  ) internal override {
    _safeMint(user, id);
  }

  function baseTokenURI() public view virtual returns (string memory) {
    return _tokenUriBase;
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
  {
    return string(abi.encodePacked(baseTokenURI(), Strings.toString(tokenId)));
  }

  function setTokenURI(string memory tokenUriBase_) public onlyOwner {
    _tokenUriBase = tokenUriBase_;
  }
}
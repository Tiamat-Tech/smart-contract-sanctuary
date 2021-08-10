// contracts/ERC721.sol
// spdx-license-identifier: mit
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Mythie is ERC721, Ownable {
  using SafeMath for uint;

  // The fixed amount of mythie tokens
  uint public totalSupply = 12;
  mapping(string => bool) _mythieExists;

  constructor() ERC721("Mythie", "MYTHIE") {}

  function getTotalySupply() public view returns (uint) {
    return totalSupply;
  }

  // function mint(address _to, string memory _tokenURI) public onlyMinter returns (bool) {
  //   // Require that token isn't alreayd minted
  //   _mintWithTokenURI(_to, _tokenURI);
  //   return true;
  // }

  function _mintWithTokenURI(address _to, string memory _tokenURI) internal {
    // uint _tokenId = totalSupply().add(1);
    // _mint(_to, _tokenId);
    // _setTokenURI(_tokenId, _tokenURI);
  }

  // function mint() {
  //   // Require ?
  //   // Mythie: add it
  //   // call the mint function
  //   // Mythie: track it
  // }
}
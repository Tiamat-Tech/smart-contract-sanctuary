// contracts/ERC721.sol
// spdx-license-identifier: mit
pragma solidity ^0.8.0;
// pragma solidity 0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Mythie is ERC721, Ownable {
  using SafeMath for uint;
  using Counters for Counters.Counter;

  /**
   * @dev The collection of minted mythie _tokenURIs
   */
  Counters.Counter private _tokenIds;

  /**
   * @dev The fixed amount of Mythie tokens
   */
  uint public totalSupply = 12;

  /**
   * @dev A mapping from NFT ID to an existance boolean
   */
  mapping(uint256 => bool) _mythieExists;

  /**
   * @dev A mapping from NFT ID to the address that owns it
   */
  mapping (uint256 => address) internal idToOwner;

  constructor() ERC721("Mythie", "MYTHIE") {
    // _setBaseURI("https://gateway.pinata.cloud/ipfs/QmWSbBa8zRA83jVfhFZPE6g2s8iWX3Sq6srkbnsoWnQ1WG?filename=");
  }

  function getTotalySupply() public view returns (uint) {
    return totalSupply;
  }

  // function mint(address _to, string memory _tokenURI) public onlyMinter returns (bool) {
  //   _mintWithTokenURI(_to, _tokenURI);
  //   return true;
  // }

  // function _mintWithTokenURI(address _to, string memory _tokenURI) internal {
  //   uint _tokenId = totalSupply().add(1);
  //   _mint(_to, _tokenId);
  //   _setTokenURI(_tokenId, _tokenURI);
  // }

  // _tokenURI is a string that should resolve to a JSON document that describes the NFT's metadata.
  // returns a number that represents the ID of the freshly minted NFT
  function mintMythie(string memory _tokenURI) public returns (uint) {
    _tokenIds.increment();
    uint256 newMythieId = _tokenIds.current();
    _mint(msg.sender, newMythieId);
    // _setTokenURI(newMythieId, tokenURI);
    _mythieExists[newMythieId] = true;

    return newMythieId;
  }
}
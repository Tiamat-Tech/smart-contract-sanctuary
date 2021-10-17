// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MythiesNFT is ERC721Enumerable, ERC721URIStorage, Ownable {
  using SafeMath for uint;
  using Counters for Counters.Counter;

  uint256 MAX_SUPPLY = 222;

  Counters.Counter private _mintedCount;

  /** @dev The collection of minted mythie _tokenURIs */
  string[] public mythies;

  // Mappings
  mapping(uint256 => bool) mythieExists;
  mapping(uint256 => address) internal tokenIdToOwner;
  mapping(string => bool) hashToMinted;
  mapping(uint256 => string) internal tokenIdToHash;

  address _owner;

  constructor() ERC721("MythiesNFT", "MYTHIE") {
    _owner = msg.sender;
    // _setBaseURI("ipfs://");
  }

  // Add payable
  // window.ethereum.selectedAddress
  // tokenURI is a string that should resolve to a JSON document that describes the NFT's metadata.
  function mintMythie(address recipient, string memory _tokenURI) public returns (uint) {
    require(totalSupply() < MAX_SUPPLY, "Purchase would exceed max supply of Mythies");
    // require(msg.value >= 0.01, "Not enough ETH sent; check price!");

    _mintedCount.increment();
    uint256 newMythieId = _mintedCount.current();

    require(newMythieId < MAX_SUPPLY, "Requested tokenId exceeds upper bound");

    _safeMint(recipient, newMythieId);
    _setTokenURI(newMythieId, _tokenURI);

    // Store the fact that this mythie now exists
    mythieExists[newMythieId] = true;

    return newMythieId;
  }

  function _baseURI() internal pure override returns (string memory) {
    return "https://gateway.pinata.cloud/ipfs/QmQ91KUpAvFhHZpg4M7zEJBdrsxFFZymcxuM3sAt92At3x/";
  }



  /** 
  * @dev Override some conflicting methods so that this contract can inherit 
  * ERC721Enumerable and ERC721URIStorage functionality
  */

  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    override(ERC721, ERC721Enumerable)
  {
    super._beforeTokenTransfer(from, to, tokenId);
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
    return super.tokenURI(tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
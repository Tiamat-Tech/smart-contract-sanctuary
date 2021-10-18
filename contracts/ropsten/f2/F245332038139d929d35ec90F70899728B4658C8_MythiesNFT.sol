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

  // Collection of minted mythie _tokenURIs
  string[] public _tokenURIs;
  // Base URI
  string private _baseURIextended;

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

  function totalSupply() public view override returns (uint) {
    return MAX_SUPPLY;
  }

  function setBaseURI(string memory baseURI_) external onlyOwner() {
    _baseURIextended = baseURI_;
  }

  function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal override virtual {
    require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
    _tokenURIs[tokenId] = _tokenURI;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseURIextended;
  }

  function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    string memory _tokenURI = _tokenURIs[tokenId];
    string memory base = _baseURI();
    
    // If there is no base URI, return the token URI.
    if (bytes(base).length == 0) {
      return _tokenURI;
    }
    // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
    if (bytes(_tokenURI).length > 0) {
      return string(abi.encodePacked(base, _tokenURI));
    }
    // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
    return string(abi.encodePacked(base, uint2str(tokenId)));
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

  // function tokenURI(uint256 tokenId) public override returns (string memory) {
  //   return "https://gateway.pinata.cloud/ipfs/QmQ91KUpAvFhHZpg4M7zEJBdrsxFFZymcxuM3sAt92At3x/"+;
  // }


  function uint2str(
    uint256 _i
  )
    internal
    pure
    returns (string memory str)
  {
    if (_i == 0)
    {
      return "0";
    }
    uint256 j = _i;
    uint256 length;
    while (j != 0)
    {
      length++;
      j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length;
    j = _i;
    while (j != 0)
    {
      bstr[--k] = bytes1(uint8(48 + j % 10));
      j /= 10;
    }
    str = string(bstr);
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

  // function tokenURI(uint256 tokenId)
  //   public
  //   view
  //   override(ERC721, ERC721URIStorage)
  //   returns (string memory)
  // {
  //   return super.tokenURI(tokenId);
  // }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
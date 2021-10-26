// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Mythies is ERC721Enumerable, ERC721URIStorage, Ownable {
  using SafeMath for uint;
  using Counters for Counters.Counter;

  Counters.Counter private _mintedCount;

  uint256 public constant MAX_SUPPLY = 222;
  uint256 public constant MAX_PUBLIC_MINT = 20;
  uint256 public constant PRICE_PER_TOKEN = 0.02 ether;

  // Base URI
  string private _baseURIextended;

  // Events
  event Minted(uint tokenId, address recipient);

  // Mappings
  mapping(uint256 => bool) public mythieExists;
  mapping(uint256 => address) public tokenIdToOwner;
  mapping(string => uint256) public tokenURItoTokenId;
  mapping(uint256 => string) internal _tokenURIs;

  address private _owner;
  // Where funds should be sent to
  address payable public fundsTo;
  // Is sale on?
  bool public sale;
  // Sale price
  uint256 public pricePer;

  constructor() ERC721("Mythies", "MYTHIE") {
    _owner = msg.sender;
    sale = false;
    pricePer = PRICE_PER_TOKEN;
  }

  function updateFundsTo(address payable newFundsTo) public onlyOwner {
    fundsTo = newFundsTo;
  }

  function updatePricePer(uint256 newPrice) public onlyOwner {
    pricePer = newPrice;
  }

  function enableSale() public onlyOwner {
    sale = true;
  }

  function disableSale() public onlyOwner {
    sale = false;
  }

  function claimBalance() public onlyOwner {
    (bool success, ) = fundsTo.call{value: address(this).balance}("");
    require(success, "transfer failed");
  }

  function mintedSupply() public view returns (uint) {
    return _mintedCount.current();
  }

  function setBaseURI(string memory baseURI_) external onlyOwner() {
    _baseURIextended = baseURI_;
  }

  function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal override {
    require(_exists(tokenId), "URI set of nonexistent token");
    _tokenURIs[tokenId] = _tokenURI;
    super._setTokenURI(tokenId, _tokenURI);
  }

  function _baseURI() internal view override returns (string memory) {
    return _baseURIextended;
  }

  // testing only
  function getBaseURI() public view virtual returns (string memory) {
    return _baseURIextended;
  }

  function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    string memory base = _baseURI();
    string memory ext = '.json';

    super.tokenURI(tokenId);

    // Concat the tokenID to the baseURI.
    return string(abi.encodePacked(base, uint2str(tokenId), ext));
  }

  function _setTokenURIforTokenId(uint256 tokenId) internal {
    string memory uri = tokenURI(tokenId);
    _setTokenURI(tokenId, uri);
    tokenURItoTokenId[uri] = tokenId;
  }

  function numAvailableToMint(address addr) external view returns (uint256) {
    return MAX_PUBLIC_MINT - balanceOf(addr);
  }

  function mintMythie(uint8 quantity) public payable {
    // Cannot mint 0
    require(quantity != 0, "Requested quantity cannot be zero");
    // Cannot mint more than max supply
    require(mintedSupply() + quantity <= MAX_SUPPLY, "Purchase would exceed max supply of Mythies");
    // Cannot mint more than the max limit per wallet
    require(balanceOf(msg.sender) + quantity <= MAX_PUBLIC_MINT, "Exceeded max available to purchase");
    // Txn must have at least quantity * price (any more is considered a tip)
    require(quantity * PRICE_PER_TOKEN <= msg.value, "Not enough ether sent");
    // Sale must be enabled
    require(sale, "Sale is not enabled");
    
    for (uint256 i = 0; i < quantity; i++) {
      _mintedCount.increment();
      uint256 newMythieId = _mintedCount.current();

      _safeMint(msg.sender, newMythieId);
      _setTokenURIforTokenId(newMythieId);

      mythieExists[newMythieId] = true;
      tokenIdToOwner[newMythieId] = msg.sender;

      emit Minted(newMythieId, msg.sender);
    }
  }

  // https://github.com/provable-things/ethereum-api/issues/102#issuecomment-760008040
  function uint2str(uint256 _i) public pure returns (string memory str) {
    if (_i == 0) { return "0"; }

    uint256 j = _i;
    uint256 length;
    while (j != 0) {
      length++;
      j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length;
    j = _i;
    while (j != 0) {
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

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
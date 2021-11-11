// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Mythies is ERC721Enumerable, ERC721URIStorage, Ownable {
  using SafeMath for uint;
  using Counters for Counters.Counter;

  Counters.Counter private _mintedCount;

  uint256 public constant MAX_SUPPLY = 222;
  uint256 public constant MAX_PUBLIC_MINT = 5;
  uint256 public constant PRICE_PER_TOKEN = 0.02 ether;
  
  // Contract-level metadata URI
  string public contractLevelURI;

  // Base URI for token metadata
  string private _baseURIextended;

  // Events
  event Minted(uint tokenId, address recipient);
  event VerifiedForWhitelist(address account, bool verified);

  // Mappings
  mapping(uint256 => bool) public mythieExists;
  mapping(uint256 => address) public tokenIdToOwner;
  mapping(string => uint256) public tokenURItoTokenId;
  mapping(uint256 => string) internal _tokenURIs;

  // Where funds should be sent to
  address payable public fundsTo;
  // Is public sale on?
  bool public publicSale;
  // Is whitelist only sale on?
  bool public whitelistSale;
  // Sale price
  uint256 public pricePer;
  // Merkle root
  bytes32 public merkleRoot;

  constructor() ERC721("Mythies", "MYTHIE") {
    whitelistSale = false;
    publicSale = false;
    pricePer = PRICE_PER_TOKEN;
    contractLevelURI = "https://gateway.pinata.cloud/ipfs/QmPVwDFFayfWYrPWy4wszdKd4G4aqfuyahEMS1KqxpmD5R";
  }

  function updateFundsTo(address payable newFundsTo) public onlyOwner {
    fundsTo = newFundsTo;
  }

  function updatePricePer(uint256 newPrice) public onlyOwner {
    pricePer = newPrice;
  }

  function enablePublicSale() public onlyOwner {
    publicSale = true;
    whitelistSale = false;
    pricePer = PRICE_PER_TOKEN;
  }

  function disablePublicSale() public onlyOwner {
    publicSale = false;
  }

  function enableWhitelistSale() public onlyOwner {
    whitelistSale = true;
    publicSale = false;
    pricePer = 0 ether;
  }

  function disableWhitelistSale() public onlyOwner {
    whitelistSale = false;
  }

  function disableAllSales() public onlyOwner {
    disablePublicSale();
    disableWhitelistSale();
  }

  function verifyWhitelistedAddress(
    address account,
    bytes32[] calldata merkleProof
  ) public returns (bool) {
    
    bytes32 node = keccak256(abi.encodePacked(account));

    // Verify the merkle proof.
    bool verified = MerkleProof.verify(merkleProof, merkleRoot, node);

    emit VerifiedForWhitelist(account, verified);

    return verified;
  }

  function setMerkleRoot(bytes32 root) public onlyOwner {
    merkleRoot = root;
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

  function setContractURI(string memory contractURI_) external onlyOwner() {
    contractLevelURI = contractURI_;
  }

  function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal override {
    require(_exists(tokenId), "URI set of nonexistent token");
    _tokenURIs[tokenId] = _tokenURI;
    super._setTokenURI(tokenId, _tokenURI);
  }

// Returns the base URI for the token metadata
  function _baseURI() internal view override returns (string memory) {
    return _baseURIextended;
  }

  // Returns the URI for the contract level metadata
  function contractURI() public view returns (string memory) {
    return contractLevelURI;
  }

  // Returns the unique token URI, given the token id
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

  function availableMintsForAddress(address addr) external view returns (uint256) {
    return MAX_PUBLIC_MINT - balanceOf(addr);
  }

  function whitelistMintMythie(address recipient, uint8 quantity, bytes32[] calldata merkleProof) public {
    // Recipient's address must be verified on the whitelist
    require(verifyWhitelistedAddress(recipient, merkleProof), 'Address is not whitelisted');
    // Cannot mint 0
    require(quantity != 0, "Requested quantity cannot be zero");
    // Cannot mint more than max supply
    require(mintedSupply() + quantity <= MAX_SUPPLY, "Purchase would exceed max supply of Mythies");
    // Cannot mint more than the max limit per wallet
    require(balanceOf(recipient) + quantity <= MAX_PUBLIC_MINT, "Exceeded max available to purchase");
    // Sale must be enabled
    require(whitelistSale == true && publicSale == false, "Public sale is not enabled");

    for (uint256 i = 0; i < quantity; i++) {
      _mintedCount.increment();
      uint256 newMythieId = _mintedCount.current();

      _safeMint(recipient, newMythieId);
      _setTokenURIforTokenId(newMythieId);

      mythieExists[newMythieId] = true;
      tokenIdToOwner[newMythieId] = recipient;

      emit Minted(newMythieId, recipient);
    }
  }

  function mintMythie(address recipient, uint8 quantity) public payable {
    // Cannot mint 0
    require(quantity != 0, "Requested quantity cannot be zero");
    // Cannot mint more than max supply
    require(mintedSupply() + quantity <= MAX_SUPPLY, "Purchase would exceed max supply of Mythies");
    // Cannot mint more than the max limit per wallet
    require(balanceOf(recipient) + quantity <= MAX_PUBLIC_MINT, "Exceeded max available to purchase");
    // Sale must be enabled
    require(publicSale == true && whitelistSale == false, "Public sale is not enabled");
    // Txn must have at least quantity * price (any more is considered a tip)
    require(quantity * pricePer <= msg.value, "Not enough ether sent");
    
    for (uint256 i = 0; i < quantity; i++) {
      _mintedCount.increment();
      uint256 newMythieId = _mintedCount.current();

      _safeMint(recipient, newMythieId);
      _setTokenURIforTokenId(newMythieId);

      mythieExists[newMythieId] = true;
      tokenIdToOwner[newMythieId] = recipient;

      emit Minted(newMythieId, recipient);
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
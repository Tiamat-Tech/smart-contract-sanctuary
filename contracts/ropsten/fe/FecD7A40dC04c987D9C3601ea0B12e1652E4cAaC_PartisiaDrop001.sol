// https://ethereum.stackexchange.com/a/93998
pragma solidity ^0.8.0;

// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract PartisiaDrop001 is ERC721URIStorage, Ownable {
  using Strings for uint256;

  // Public attributes about drops
  uint16 public constant maxSupply = 500;
  uint256 public dropStartsAt;
  uint256 public dropEndsAt;

  // Base URI
  string private _baseURIextended;

  address[] private _whitelists;
  uint16 private _idx = 0;

  // 2.5 ETH
  uint256 private _amount = 2500000000000000000;
  // address private _to; // = address(0x0);

  uint256 private _auctionTimeEnd;

  // more efficient pattern to use a mapping over iterating through an array
  mapping(address => bool) _addressMinted;
  mapping(uint16 => bool) _idxExists;
  mapping(address => bool) _whitelist;
  mapping(address => bool) public whitelist;

  constructor() ERC721("Partisia", "PARTISIA") { }

  function withdraw(address _to) public onlyOwner {
      uint256 balance = address(this).balance;
      // https://solidity-by-example.org/sending-ether/
      (bool sent, bytes memory data) = _to.call{value: balance}("");
      require(sent, "Failed to send Ether");
  }

  // Include the foward slash in the baseURI_ call
  function setBaseURI(string memory baseURI_) external onlyOwner {
      _baseURIextended = baseURI_;
  }

  function setWhitelistAndTime(
      address[] memory addresses,
      uint256 timeStart,
      uint256 timeEnd
  ) external onlyOwner {
      // add the addresses
      for (uint16 i = 0; i < addresses.length; i++) {
        whitelist[addresses[i]] = true;
      }
      dropStartsAt = timeStart;
      dropEndsAt = timeEnd;
  }

  function addToWhitelist(address[] memory addresses) external onlyOwner{
    for (uint16 i = 0; i < addresses.length; i++) {
      whitelist[addresses[i]] = true;
    }
  }

  function isWhitelisted(address addr) public view returns (bool) {
    return whitelist[addr];
  }

  function setDropTime(uint256 timeStart, uint256 timeEnd) external onlyOwner {
    dropStartsAt = timeStart;
    dropEndsAt = timeEnd;
  }

  // function setAddressPayable(address to_) external onlyOwner {
  //     _to = to_;
  // }

  function setMintAmount(uint256 amount_) external onlyOwner {
      _amount = amount_;
  }

  function _baseURI() internal view virtual override returns (string memory) {
      return _baseURIextended;
  }

  function totalSupply() public view virtual returns (uint256) {
      return _idx;
  }

  // function getAddressPayable() public view virtual returns (address) {
  //     return _to;
  // }

  function getMintAmount() public view virtual returns (uint256) {
      return _amount;
  }

  function getBaseUri() public view virtual returns (string memory) {
      return _baseURIextended;
  }

  function getAuctionTime() public view virtual returns (uint256[2] memory) {
      return [dropStartsAt, dropEndsAt];
  }

  // function mint(uint16 _idx) public {
  // The index does not matter; all the same
  function mint() external payable returns (uint256) {
      // Increment the index
      _idx++; // Test that this doesn't incremet if minting fails
      // idx is between 1 and 500
      require(_idx >= 1, "Invalid index");
      require(_idx <= maxSupply, "Exceeds max supply");

      // make sure it is not already minted
      require(!_idxExists[_idx], "NFT index already minted");

      // move the balances
      require(msg.value == _amount, "Incorrect ether amount sent.");
      // block.timestamp is in seconds
      // Note: Switched this to use a unix timestamp
      require(block.timestamp >= dropStartsAt , "Invalid block start time");
      require(block.timestamp <= dropEndsAt, "Invalid block end time");

      // require that the address is whitelisted
      require(whitelist[msg.sender], "Address not whitelisted");

      // Same address cannot mint more than one NFT
      require(!_addressMinted[msg.sender], "Address has already minted");

      // actually do the mint
      _mint(msg.sender, _idx);

      // add the index into the mappings
      _setTokenURI(_idx, uint256(_idx).toString());
      _idxExists[_idx] = true;
      _addressMinted[msg.sender] = true;

      return _idx;
  }
}
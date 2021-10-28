// https://ethereum.stackexchange.com/a/93998
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract PartisiaDrop001 is ERC721URIStorage, Ownable {
  using SafeMath for uint256;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  // Public attributes about drops
  uint16 public constant maxSupply = 1111;
  uint public constant maxMints = 20; // This is max mints per transaction
  uint public constant maxTotalMints = 25; // This is the total mints limited per address
  uint256 public dropStartsAt;
  uint256 public dropEndsAt;
  uint256 public nftUnitPrice = .01 ether; //2500000000000000000; 2.5 ETH

  // Base URI
  string private _baseURIextended;

  address[] private _whitelists;

  event Minted(address indexed _who, uint8 indexed _amount);

  // address private _to; // = address(0x0);

  // more efficient pattern to use a mapping over iterating through an array
  mapping(address => uint) _addressMinted;
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

  function setDropTime(uint256 timeStart, uint256 timeEnd) external onlyOwner {
    dropStartsAt = timeStart;
    dropEndsAt = timeEnd;
  }

  function setMintAmount(uint256 amount) external onlyOwner {
    nftUnitPrice = amount;
  }

  function _baseURI() internal view virtual override returns (string memory) {
      return _baseURIextended;
  }

  function totalSupply() public view virtual returns (uint256) {
      return _tokenIds.current();
  }

  function getMintAmount() public view virtual returns (uint256) {
      return nftUnitPrice;
  }

  function getBaseUri() public view virtual returns (string memory) {
      return _baseURIextended;
  }

  function getAuctionTime() public view virtual returns (uint256[2] memory) {
      return [dropStartsAt, dropEndsAt];
  }

  function hasMinted(address addr) public view returns(uint) {
    return _addressMinted[addr];
  }

  function numRemaining(address addr) public view returns(uint) {
    return maxTotalMints - _addressMinted[addr];
  }

  function mint(uint numberOfTokens) external payable {
    require(numberOfTokens <= maxMints, "Purchase is over maximum mint quantity");
    require((_addressMinted[msg.sender] + numberOfTokens) <= maxTotalMints , "This exceeds the max mint limit");
    require(_tokenIds.current().add(numberOfTokens) <= maxSupply, "Purchase would exceed total supply");
    require(nftUnitPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
    require(block.timestamp >= dropStartsAt , "Invalid block start time");
    require(block.timestamp <= dropEndsAt, "Invalid block end time");
    require(whitelist[msg.sender], "Address not whitelisted");

    for(uint i=0; i < numberOfTokens; i++) {
      _tokenIds.increment();
      uint256 _idx = _tokenIds.current();
      _mint(msg.sender, _idx);
      _setTokenURI(_idx, Strings.toString(_idx));
    }
    // Can this partially mint and not reach this line?
    _addressMinted[msg.sender] = _addressMinted[msg.sender] + numberOfTokens;
    emit Minted(msg.sender, uint8(numberOfTokens));
  }
}
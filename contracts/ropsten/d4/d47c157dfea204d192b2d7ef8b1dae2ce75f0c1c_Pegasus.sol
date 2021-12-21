pragma solidity 0.7.5;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface FuelERC20 {
  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool);
}

contract Pegasus is ERC721, Ownable {
  using Counters for Counters.Counter;
  using SafeMath for uint256;

  address fuelToken;
  address treasury;
  uint256 public tokenValue;
  Counters.Counter private _tokenIdCounter;

  event NFTMinted(uint256 tokenId, address owner);
  event LevelUp(uint16 tokenID, address caller, address owner);

  constructor(address _fuelToken, address _treasury) ERC721("Pegasus", "Pega") {
    fuelToken = _fuelToken;
    tokenValue = 0;
    treasury = _treasury;
  }

  //token id to nft level
  mapping(uint32 => uint16) public levels;

  function safeMint(address to) public onlyOwner {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
    levels[uint32(tokenId)] = 1;
    tokenValue = tokenValue.add(500 * 10**9);
    emit NFTMinted(tokenId, to);
  }

  function getLevel(uint16 tokenId) public view returns (uint16) {
    return levels[tokenId];
  }

  function levelUp(uint16 tokenId) external {
    require(msg.sender == ownerOf(tokenId), "Caller is not owner");
    uint16 curLevel = levels[tokenId];
    FuelERC20(fuelToken).transferFrom(
      msg.sender,
      treasury,
      500 * curLevel * 10**uint256(9)
    );
    tokenValue = tokenValue.add(500 * 10**9);
    levels[tokenId] += 1;
  }
}
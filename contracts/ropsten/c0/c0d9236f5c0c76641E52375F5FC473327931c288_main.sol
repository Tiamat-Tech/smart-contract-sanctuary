pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract main is ERC721 {
using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;

 constructor() public ERC721("test university", "tu") {}

 mapping(string => uint8) internal hashes;

 mapping(uint256 => string) public tokenId;

function addItem(address recipient, string memory hash, string memory metadata)
  public
  returns (uint256)
{
  require(hashes[hash] != 1);

  hashes[hash] = 1;

  _tokenIds.increment();

  uint256 newItemId = _tokenIds.current();

  _mint(recipient, newItemId);

  setTokenURI( newItemId, metadata);

  return newItemId;
}

function setTokenURI(uint256 newItemId, string memory metadata)
internal
{
    tokenId[newItemId] = metadata;
}
}
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NiftyHair is ERC721, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() public ERC721("Nifty Hair", "NFTH") {}

  function mintNFTH(address _recipient, string memory _tokenURI) public onlyOwner returns (uint256) {
    _tokenIds.increment();

    uint256 newItemId = _tokenIds.current();

    _mint(_recipient, newItemId);
    _setTokenURI(newItemId, _tokenURI);

    return newItemId;
  }
}
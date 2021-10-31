// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./StringUtils.sol";

contract SphereXNFT is ERC721URIStorage, ReentrancyGuard, Ownable, StringUtils {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  uint256 public constant MAX_NFT_SUPPLY = 500;
  bool public saleIsActive = false;
  uint256 public constant PRICE = 25000000000000000;

  constructor() ERC721("SphereX", "SPHEREX") {}

  function createToken(string memory title, string memory imageURI)
    public
    payable
    nonReentrant
    returns (uint256)
  {
    require(totalSupply() < MAX_NFT_SUPPLY, "Sale has already ended");
    require(
      msg.value >= PRICE,
      "So...the price must be equal to listing price"
    );
    _tokenIds.increment();
    uint256 newTokenID = _tokenIds.current();
    _safeMint(msg.sender, newTokenID);

    string memory _newTokenURI = formatTokenURI(
      title,
      "Randomly generated sphere",
      imageURI
    );

    _setTokenURI(newTokenID, _newTokenURI);

    return newTokenID;
  }

  function totalSupply() public view returns (uint256) {
    return _tokenIds.current();
  }

  function withdraw() public {
    uint256 balance = address(this).balance;

    payable(owner()).transfer(balance);
  }

  function setSaleIsActive(bool saleIsActive_) external onlyOwner {
    saleIsActive = saleIsActive_;
  }
}
// SPDX-License-Identifier: Lincoin
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @custom:security-contact [email protected]
contract DrunkApes is ERC721, AccessControl {
  using Counters for Counters.Counter;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  Counters.Counter private _tokenIdCounter;

  uint256 public constant MAX_SUPPLY = 10;

  constructor() ERC721("DrunkApes", "DAPS") {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MINTER_ROLE, msg.sender);
  }

  function _baseURI() internal pure override returns (string memory) {
    return "ipfs://bafybeihpjhkeuiq3k6nqa3fkgeigeri7iebtrsuyuey5y6vy36n345xmbi/";
  }

  function safeMint(address to) public onlyRole(MINTER_ROLE) {
    uint256 tokenId = _tokenIdCounter.current();

    require(tokenId < MAX_SUPPLY, "all tokens are minted");

    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
  }

  // The following functions are overrides required by Solidity.

  function supportsInterface(bytes4 interfaceId)
  public
  view
  override(ERC721, AccessControl)
  returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
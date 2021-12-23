// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {EPSProxy} from "./EPSProxy.sol";

contract ProxyCallingMinter is
  ERC721,
  EPSProxy
{
  using Counters for Counters.Counter;
  
  EPSProxy eps = EPSProxy(0x8AA42062fe37bB4E983058F96672EfDC929fDEe0); // Include the address of the EPS Proxy Registry
  address constant REQUIRED_NFT = 0xB0b6b7C52BE3a3DAD39fDDD142bc613F3e1C4F09; 
  Counters.Counter private _tokenIdCounter;
  
  constructor(
  ) ERC721("ProxyEnabledMinter", "PROXYMINT") {

  }

  function mint() public {
    performMint(msg.sender, msg.sender);
  }

  function mintFromProxiedCall() public {
    address owner;
    address delivery;
    (owner, delivery) = eps.getSignerOwnerAndDeliveryAddress();
    performMint(owner, delivery);
  }

  function performMint(address assetOwner, address to) internal {
    // Can only mint if have a non-0 balance of our magic NFT token:
    uint256 eligibleNFTBalance = (ERC721(REQUIRED_NFT).balanceOf(assetOwner));
    require(eligibleNFTBalance > 0, "Sorry, you do not hold the required NFT");

    // They have the required NFT, mint our derivative to the delivery address:   
    _safeMint(to, _tokenIdCounter.current());
    _tokenIdCounter.increment();
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function _baseURI() internal pure override returns (string memory) {
    return "https://ipfs.moralis.io:2053/ipfs/QmaZqT1tA7WLodaiDCz9NjZLjvCn3LHGCWtV94ujAxMXTi";
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    return _baseURI();
  }

  // The following function is an override required by Solidity.
  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
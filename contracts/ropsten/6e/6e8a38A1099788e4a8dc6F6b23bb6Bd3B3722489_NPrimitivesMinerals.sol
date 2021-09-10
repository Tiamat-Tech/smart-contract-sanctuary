//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./core/NPassCore.sol";
import "./interfaces/IN.sol";

/**
 * @title NPrimitivesMinerals
 * @author NPrimitives (twitter.com/nprimitives) <[email protected]>
 */
contract NPrimitivesMinerals is NPassCore {
  using Strings for uint256;

  constructor(
    address _nContractAddress,
    string memory name,
    string memory symbol,
    bool onlyNHolders,
    uint256 maxTotalSupply,
    uint16 reservedAllowance,
    uint256 priceForNHoldersInWei,
    uint256 priceForOpenMintInWei
   ) 
   NPassCore(name, symbol, IN(_nContractAddress), onlyNHolders, maxTotalSupply, reservedAllowance, priceForNHoldersInWei, priceForOpenMintInWei) {}

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
      require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

      string memory baseURI = _baseURI();
      return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
  }

  function _baseURI() internal view virtual override returns (string memory) {
      return "ipfs://bafybeign7neajmv4kkxgk7ects5uw5jyktni7crvaqexnyngfn526nnv4y/output/";
  }
}
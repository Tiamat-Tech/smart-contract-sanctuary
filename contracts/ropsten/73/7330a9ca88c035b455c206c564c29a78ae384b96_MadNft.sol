pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import { IERC2981Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import { AddressUpgradeable as Address } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import { MadNftBase } from "./MadNftBase.sol";
import { RoyaltyBase } from "./RoyaltyBase.sol";

contract MadNft is
  Initializable,
  UUPSUpgradeable,
  OwnableUpgradeable,
  MadNftBase,
  RoyaltyBase
{
  using Address for address;

  // Upgrade functions
  function initialize(string memory _baseURI) public override initializer {
    name = "MADinArt NFT";
    symbol = "MAD";
    __Ownable_init();
    __EIP712_init_unchained("MadInArt NFT", "1");
    super.initialize(_baseURI);
  }

  function _authorizeUpgrade(address) internal override onlyOwner {}

  function upgrade(string memory _name, string memory _symbol, string memory _baseURI) public onlyOwner {
    name = _name;
    symbol = _symbol;
    _setURI(_baseURI);
  }

  /* Public or External Functions */
  function royaltyInfoAdmin(uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
    receiver = fundAccount;
    royaltyAmount = (salePrice * royaltyPercentageForAdmin) / 10000;
  }

  function instantMint(InstantMintSubject memory _subject, bytes memory _signature)
    external
    payable
  {
    _instantMint(_subject, _signature);
  }

  function instantMintBatch(InstantMintBatchSubject memory _subject, bytes memory _signature)
    external
    payable
  {
    _instantMintBatch(_subject, _signature);
  }

  function instantMintWithRoyalty(InstantMintSubject memory _subject, bytes memory _signature, RoyaltyDistribution[] memory _distributions)
    external
    payable
    validDistributions(_distributions)
  {
    _instantMint(_subject, _signature);
    for(uint256 i = 0; i < _distributions.length; i ++) {
      RoyaltyDistribution memory distribution = _distributions[i];
      if (distribution.percentage > 0) {
        uint256 royaltyAmount = (msg.value * distribution.percentage) / 10000;
        payable(distribution.receiver).transfer(royaltyAmount);
        // address receiver = distribution.receiver;
        // receiver.sendValue(royaltyAmount);
      }
    }
  }
}
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC1155PresetMinterPauserUpgradeable as ERC1155Base } from "@openzeppelin/contracts-upgradeable/token/ERC1155/presets/ERC1155PresetMinterPauserUpgradeable.sol";

contract MadNft is
  Initializable,
  UUPSUpgradeable,
  OwnableUpgradeable,
  ERC1155Base
{
  function initialize(string memory uri) public override initializer {
    __Ownable_init();
    super.initialize(uri);
  }

  function _authorizeUpgrade(address) internal override onlyOwner {}
}
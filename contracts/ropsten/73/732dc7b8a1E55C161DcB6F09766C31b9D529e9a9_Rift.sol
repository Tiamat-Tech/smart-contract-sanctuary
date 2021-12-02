// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Interfaces.sol";

contract Rift is Ownable {
  // struct to store a stake's token, owner, and earning values
  struct Stake {
    uint80 lastCharge;
    uint80 stakeDate;
    address owner;
  }

  struct Bag {
      uint16 charges;
      uint16 attunement;
      address owner;
      uint256 consumed;
  }

  uint32 public totalBagsStaked = 0;
  uint32 public SACRAFICE_COST = 2;
  uint256 public crystalPower = 0;
  uint256 public crystalsSacraficed = 0;
  uint256 public constant CHARGE_TIME = 1 days;

  ERC721 public iLoot;
  ICrystals public iCrystals;
  // IMana public iMana;

  string public description = "Unknown";

  mapping(uint256 => Stake) public rift;
  mapping(uint256 => Bag) public bags;
  mapping(address => uint256) public karma;
  
  mapping(address => uint32) public naughty;

  constructor(address crystalsAddress) Ownable() {
    iCrystals = ICrystals(crystalsAddress);
  }

  function ownerSetDescription(string memory desc) public onlyOwner {
      description = desc;
  }

  function ownerSetCrystalsAddress(address addr) public onlyOwner {
      iCrystals = ICrystals(addr);
  }

  function ownerSetLootAddress(address addr) public onlyOwner {
      iLoot = ERC721(addr);
  }

  // function ownerSetManaAddress(address addr) public onlyOwner {
  //     iMana = IMana(addr);
  // }

  function getRiftLevel() public view returns (uint256) {
    return 1 + crystalPower / SACRAFICE_COST;
  }

  function stakeBags(uint32[] calldata bagIds) external {
    for (uint i = 0; i < bagIds.length; i++) {
      _stake(bagIds[i]);
    }
  }

  function _stake(uint32 bagId) _bagCheck(bagId) _isUnstaked(bagId) internal {
    rift[bagId] = Stake({
      lastCharge: uint80(block.timestamp),
      stakeDate: uint80(block.timestamp),
      owner: _msgSender()
    });

    if (bags[bagId].owner != _msgSender()) {
      bags[bagId] = Bag({
        attunement: 1,
        charges: bags[bagId].owner == address(0) ? 1 : 0, // start your journey filled with energy
        consumed: bags[bagId].consumed,
        owner: _msgSender()
      });
    }

    totalBagsStaked += 1;
  }

  function _useCharge(uint32 bagId, uint16 amount, bool unstake)
    _bagCheck(bagId)
    _isStaked(bagId)
    _updateCharge(bagId)
    internal
  {
    require(bags[bagId].charges >= amount, "NOT ENOUGH CHARGE");

    bags[bagId].charges -= amount;
    bags[bagId].consumed += amount;

    rift[bagId].lastCharge = uint80(block.timestamp);
    rift[bagId].stakeDate = uint80(block.timestamp);

    if (unstake) {
      delete rift[bagId];
      iCrystals.safeTransferFrom(address(this), _msgSender(), bagId, "");
    }
  }

  function useCharge(uint32 bagId, uint16 amount, bool unstake) external {
    _useCharge(bagId, amount, unstake);
  }

  function growTheRift(uint256 crystalId) external {
    uint256 powerIncrease = iCrystals.crystalsMap(crystalId).level;
    (bool success,) = address(iCrystals).delegatecall(
      abi.encodeWithSignature("burn(uint256)", crystalId)
    );

    if (success) {
      crystalPower += powerIncrease;
      karma[_msgSender()] += powerIncrease;
      crystalsSacraficed += 1;
    }
  }

  modifier _bagCheck(uint32 bagId) {
    if (iLoot.ownerOf(bagId) != _msgSender()) {
      naughty[_msgSender()] += 1;
      revert("NAUGHTY");
    }
    _;
  }

  modifier _isUnstaked(uint32 bagId) {
    require(rift[bagId].stakeDate == 0, "ALREADY STAKED");
    _;
  }

  modifier _isStaked(uint32 bagId) {
    require(rift[bagId].stakeDate != 0, "NOT STAKED");
    _;
  }

  modifier _updateCharge(uint32 bagId) {
    if (bags[bagId].charges == getRiftLevel()) {
      _;
    }

    uint16 charges = uint16(block.timestamp - rift[bagId].lastCharge / CHARGE_TIME);
    if (charges > 0) {
      bags[bagId].charges = uint16(getRiftLevel() >= charges + bags[bagId].charges
        ? bags[bagId].charges + charges
        : getRiftLevel());

      rift[bagId].lastCharge = uint80(block.timestamp);
    }
    _;
  }
}
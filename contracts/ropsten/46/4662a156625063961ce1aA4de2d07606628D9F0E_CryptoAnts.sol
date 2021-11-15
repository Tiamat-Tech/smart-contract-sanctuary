//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/ICryptoAnts.sol';
import './interfaces/IEgg.sol';

enum ReasonToKill {
  SOLD,
  FAIL_HATCH
}

contract CryptoAnts is ERC721, ICryptoAnts {
  address internal _owner;
  bool internal _locked = false;

  IEgg public immutable override eggs;
  mapping(uint256 => address) public override antToOwner;
  mapping(uint256 => uint256) public override antToHatchTime;
  uint256 public override antsCreated = 0;
  uint256 public override eggPrice = 0.01 ether;
  uint256 public override probOfDeath = 30;

  constructor(address _eggs, address __owner) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
    _owner = __owner;
  }

  function _rand(uint256 _mod) private view returns (uint256) {
    uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, antsCreated, eggs.balanceOf(msg.sender))));
    return (rand % _mod) + 1;
  }

  function _killAnt(uint256 _antId, ReasonToKill _reason) private {
    delete antToOwner[_antId];
    _burn(_antId);
    emit AntDead(msg.sender, _antId, uint256(_reason));
  }

  function updateEggPrice(uint256 _price) public onlyOwner {
    eggPrice = _price;
  }

  function updateProbOfDeath(uint256 _prob) public onlyOwner {
    probOfDeath = _prob;
  }

  function buyEggs(uint256 _amount) external payable override {
    if (_amount == 0) {
      revert AmountCannotBeZero();
    }

    if (msg.value != (_amount * eggPrice)) {
      revert NotExactAmount();
    }

    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, _amount);
  }

  function sellAnt(uint256 _antId) external onlyAntOwner(_antId) lock {
    uint256 sellValue = 0.004 ether;
    if (address(this).balance < sellValue) revert NotEnoughContractBalance();

    _killAnt(_antId, ReasonToKill.SOLD);
    /* solhint-disable avoid-low-level-calls */
    (bool success, ) = msg.sender.call{value: sellValue}('');
    if (!success) revert CallFailed();
  }

  function createAnt() external {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();
    uint256 _antId = antsCreated;
    if (antToOwner[_antId] != address(0)) revert AlreadyExists();

    antToOwner[_antId] = msg.sender;
    antsCreated++;

    eggs.burn(msg.sender, 1);
    emit EggsBurn(msg.sender, 1);
    _mint(msg.sender, _antId);
    emit AntCreated(msg.sender, _antId);
  }

  function hatch(uint256 _antId) public onlyAntOwner(_antId) enabledToHatch(_antId) {
    if (_rand(100) <= probOfDeath) {
      _killAnt(_antId, ReasonToKill.FAIL_HATCH);
    }

    uint256 maxAmountOfEggsCreated = 10;
    uint256 amount = _rand(maxAmountOfEggsCreated);
    antToHatchTime[_antId] = block.timestamp + 10 minutes;
    eggs.mint(msg.sender, amount);
    emit EggsMinted(_antId, msg.sender, amount);
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  modifier lock() {
    if (_locked) revert NoReentrancy();
    _locked = true;
    _;
    _locked = false;
  }

  modifier onlyOwner() {
    if (msg.sender != _owner) revert Unauthorized();
    _;
  }

  modifier onlyAntOwner(uint256 _antId) {
    if (msg.sender != antToOwner[_antId]) revert Unauthorized();
    _;
  }

  modifier enabledToHatch(uint256 _antId) {
    if (antToHatchTime[_antId] != 0 && block.timestamp < antToHatchTime[_antId]) {
      revert HatchNotEnabled();
    }
    _;
  }
}
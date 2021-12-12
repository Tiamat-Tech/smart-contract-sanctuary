//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IEgg is IERC20 {
  function mint(address to, uint256 amount) external;
  function burn(address to, uint256 amount) external;
}

interface IAnt is IERC721 {
  function safeMint(address to) external returns (uint256);
  function burn(uint256 tokenId) external;
}

interface IVote is IERC20 {
  function mint(address to, uint256 amount) external;
}

contract Exchange {
  IEgg public immutable eggs;
  IAnt public immutable ants;
  IVote public immutable votes;

  address public governance;
  mapping(uint256 => uint256) public antHatchLastRun;
  uint256 public eggPrice = 0.01 ether;
  uint8 public maxEggsToHatch = 20;
  uint256 public antDieChance = 5;
  uint256 public minHatchIntervalTime = 10 minutes;

  event EggPriceChanged(uint256 newPrice);
  event EggsBought(address indexed buyer, uint256 amount);
  event EggsHatched(address indexed buyer, uint256 amount);
  event AntCreated(address indexed creator, uint256 id);
  event AntSold(address indexed seller, uint256 amount, uint256 price);
  event AntDied(uint256 id);

  constructor(
    address _eggs,
    address _ants,
    address _governance,
    address _votes
  ) {
    eggs = IEgg(_eggs);
    ants = IAnt(_ants);
    governance = _governance;
    votes = IVote(_votes);
  }

  modifier onlyGovernance() {
    require(msg.sender == governance, 'Governance only!');
    _;
  }

  function changeEggPrice(uint256 _eggPrice) external onlyGovernance {
    eggPrice = _eggPrice;
    emit EggPriceChanged(eggPrice);
  }

  function buyEggs(uint256 _amount) external payable {
    require(msg.value >= (_amount * eggPrice), 'Value sent is not enough.');
    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, eggs.balanceOf(msg.sender));
  }

  function createAnt() external returns (uint256 tokenId) {
    require(eggs.balanceOf(msg.sender) >= 1, 'You need to buy eggs first.');
    eggs.burn(msg.sender, 1);
    tokenId = ants.safeMint(msg.sender);
    require(tokenId >= 0, 'Could not mint Ant.');
    votes.mint(msg.sender, 1);
    emit AntCreated(msg.sender, tokenId);
  }

  function sellAnt(uint256 _antId, uint256 price) external {
    require(price < eggPrice, 'Price is too high.');
    ants.burn(_antId);
    payable(msg.sender).transfer(price);
    emit AntSold(msg.sender, 1, price);
  }

  function hatchEggs(uint256 antId) external minHatchInterval(antId) {
    require(ants.ownerOf(antId) == msg.sender, 'You are not the owner of this ant.');
    _mintHatchedEggs();
    if (_shouldDie()) {
      _killAnt(antId); /* The ant dies after hatching eggs */
    }
  }

  modifier minHatchInterval(uint256 antId) {
    require(block.timestamp - antHatchLastRun[antId] > minHatchIntervalTime, 'Should wait hatch interval.');
    antHatchLastRun[antId] = block.timestamp;
    _;
  }

  function _mintHatchedEggs() internal {
    uint8 eggsToHatch = uint8(_random() % uint256(maxEggsToHatch));
    eggs.mint(msg.sender, eggsToHatch);
    emit EggsHatched(msg.sender, eggsToHatch);
  }

  function _killAnt(uint256 antId) internal {
    ants.burn(antId);
    emit AntDied(antId);
  }

  function _shouldDie() internal view returns (bool) {
    return _random() % antDieChance == 0; /* e.g. 1/5 chance */
  }

  function _random() private view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
  }
}
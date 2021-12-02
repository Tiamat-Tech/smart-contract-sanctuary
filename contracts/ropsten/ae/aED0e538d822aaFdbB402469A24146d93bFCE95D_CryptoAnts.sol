//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './IEgg.sol';
import './IAnts.sol';

interface ICryptoAnts {
  // Errors
  error NoEggs();
  error NotEnoughEther();
  error AntLayEggsDelay();
  // Domain events
  event EggsBought(address buyer, uint256 amount);
  event AntSold(uint256 antTokenId);
  event AntCreated(uint256 antTokenId);
  event LaidEggs(uint256 antTokenId, uint256 amount);
  event AntDied(uint256 antTokenId);
  // Updating parameters
  event EggPriceUpdated(uint256 newValue);
  event EggLayingMinUpdated(uint256 newValue);
  event EggLayingMaxUpdated(uint256 newValue);
  event EggLayingDelayUpdated(uint256 newValue);
  event EggLayingDeathRatioUpdated(uint256 newValue);

  // Domain
  function buyEggs(uint256 amount) external payable;

  function hatchEgg() external;

  function sellAnt(uint256 antTokenId, uint256 sellPrice) external;

  function layEggs(uint256 antTokenId) external;

  // Updating parameters
  function updateEggPrice(uint256 newValue) external;

  function updateEggLayingMin(uint256 newValue) external;

  function updateEggLayingMax(uint256 newValue) external;

  function updateEggLayingDelay(uint256 newValue) external;

  function updateEggLayingDeathRatio(uint256 newValue) external;
}

contract CryptoAnts is ICryptoAnts, ReentrancyGuard, Ownable {
  // EGG ERC0 token
  IEgg public immutable eggs;

  // ANT ERC721 Token
  IAnts public immutable ants;

  // EGG price
  uint256 public eggPrice = 0.01 ether;

  // Ants egg laying.
  uint256 public antLayEggsMin = 1; // Min. amount of eggs laid
  uint256 public antLayEggsMax = 15; // Max. amount of eggs laid
  uint256 public antLayEggsDelay = 10 minutes; // Egg layings cooldown per ant
  uint256 public antLayEggsDeathRatio = 13; // % ants dies when laying eggs

  // Maps ANT token IDs to egg laying timestamps
  mapping(uint256 => uint256) private _lastEggLaid;

  constructor(
    address _eggs,
    address _ants,
    address governance
  ) {
    eggs = IEgg(_eggs);
    ants = IAnts(_ants);
    transferOwnership(governance);
  }

  function buyEggs(uint256 amount) external payable override nonReentrant {
    uint256 eggsCallerCanBuy = msg.value / eggPrice;
    if (eggsCallerCanBuy < amount) {
      revert NotEnoughEther();
    }
    eggs.mint(msg.sender, amount);
    emit EggsBought(msg.sender, amount);
  }

  function hatchEgg() external override nonReentrant {
    if (eggs.balanceOf(msg.sender) < 1) {
      revert NoEggs();
    }
    uint256 antTokenId = ants.totalSupply();
    ants.mint(msg.sender, antTokenId);
    eggs.burn(msg.sender, 1);
    emit AntCreated(antTokenId);
  }

  function sellAnt(uint256 antTokenId, uint256 sellPrice) external override nonReentrant {
    require(ants.ownerOf(antTokenId) == msg.sender, 'Unauthorized');
    require(sellPrice < eggPrice, 'Too expensive');
    ants.burn(antTokenId);
    // solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: sellPrice}('');
    require(success, 'Whoops, this call failed!');
    emit AntSold(antTokenId);
  }

  function layEggs(uint256 antTokenId) external override nonReentrant {
    require(ants.ownerOf(antTokenId) == msg.sender, 'Unauthorized');
    if (_antCantLayEggs(antTokenId)) {
      revert AntLayEggsDelay();
    }
    if (_antShouldDie()) {
      ants.burn(antTokenId);
      emit AntDied(antTokenId);
      return;
    }
    _lastEggLaid[antTokenId] = block.timestamp;
    uint256 eggAmount = _randomEggAmount();
    eggs.mint(msg.sender, eggAmount);
    emit LaidEggs(antTokenId, eggAmount);
  }

  // Setters
  function updateEggPrice(uint256 newValue) external override onlyOwner {
    require(newValue > 0, 'Invalid value');
    if (newValue != eggPrice) {
      eggPrice = newValue;
    }
    emit EggPriceUpdated(newValue);
  }

  function updateEggLayingMin(uint256 newValue) external override onlyOwner {
    require(newValue < antLayEggsMax, 'Invalid value');
    if (newValue != antLayEggsMin) {
      antLayEggsMin = newValue;
    }
    emit EggLayingMinUpdated(newValue);
  }

  function updateEggLayingMax(uint256 newValue) external override onlyOwner {
    require(newValue > antLayEggsMin, 'Invalid value');
    if (newValue != antLayEggsMax) {
      antLayEggsMax = newValue;
    }
    emit EggLayingMaxUpdated(newValue);
  }

  function updateEggLayingDelay(uint256 newValue) external override onlyOwner {
    if (newValue != antLayEggsDelay) {
      antLayEggsDelay = newValue;
    }
    emit EggLayingDelayUpdated(newValue);
  }

  function updateEggLayingDeathRatio(uint256 newValue) external override onlyOwner {
    require(newValue >= 0 && newValue <= 100, 'Invalid value');
    if (newValue != antLayEggsDeathRatio) {
      antLayEggsDeathRatio = newValue;
    }
    emit EggLayingDeathRatioUpdated(newValue);
  }

  // Private
  function _randomEggAmount() private view returns (uint256) {
    return antLayEggsMin + (block.timestamp % (antLayEggsMax - antLayEggsMin));
  }

  function _antCantLayEggs(uint256 antTokenId) private view returns (bool) {
    return (block.timestamp - _lastEggLaid[antTokenId]) < antLayEggsDelay;
  }

  function _antShouldDie() private view returns (bool) {
    return (block.timestamp % 100) < antLayEggsDeathRatio;
  }
}
//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import './interfaces/IEgg.sol';
import './interfaces/ICryptoAnts.sol';

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract CryptoAnts is Ownable, ERC721, ICryptoAnts, ReentrancyGuard {
  IEgg public immutable override eggs;
  uint256 public override eggPrice = 0.01 ether;
  uint256 public override antPrice = 0.004 ether;
  uint256 public override antsCreated = 0;
  mapping(uint256 => address) public antToOwner;

  /// Period of time required for an ant to be able to hatch/create new eggs again
  uint256 public hatchPeriod = 10 minutes;
  /// Max number of eggs an ant can hatch at a time
  uint256 public newEggsRange = 20;
  /// Probability an ant has of dying when creating new eggs
  uint256 public probabilityOfDying = 30;
  /// Last time each ant created new eggs (_antId => block.timestamp)
  mapping(uint256 => uint256) public antToLastHatchTime;

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
  }

  /// @notice This external function enables Governance to modify the price of the egg
  function setEggPrice(uint256 _newPrice) external override onlyOwner {
    eggPrice = _newPrice;
  }

  /// @notice This external function enables Governance to modify the price of the ant
  function setAntPrice(uint256 _newPrice) external override onlyOwner {
    antPrice = _newPrice;
  }

  /// @notice This external function enables Governance to modify the new eggs range
  function setNewEggsRange(uint256 _newEggsRange) external override onlyOwner {
    newEggsRange = _newEggsRange;
  }

  /// @notice This external function enables Governance to modify ant's probability of dying
  function setProbabilityOfDying(uint256 _newProbabilityOfDying) external override onlyOwner {
    probabilityOfDying = _newProbabilityOfDying;
  }

  function buyEggs(uint256 _amount) external payable override nonReentrant {
    if (msg.value != eggPrice * _amount) revert WrongEtherSent();
    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, _amount);
  }

  function sellAnt(uint256 _antId) external override nonReentrant {
    /// @dev use of Checks-Effects-Interactions pattern to avoid reentrancy attacks
    if (antToOwner[_antId] != msg.sender) revert Unauthorized();
    if (address(this).balance < antPrice) revert NotEnoughContractBalance();

    delete antToOwner[_antId];
    _burn(_antId);
    emit AntSold();

    // solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: antPrice}('');
    if (!success) revert CallFailed();
  }

  function createAnt() external override {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();

    uint256 _antId = antsCreated++;
    /// @dev All addresses in the mapping are initialized to zero, so we can avoid overwriting by checking the value
    if (antToOwner[_antId] != address(0)) revert AlreadyExists();
    antToOwner[_antId] = msg.sender;

    _mint(msg.sender, _antId);
    emit AntCreated();

    /// @dev Burn the egg used to create the ant, otherwise caller can create infinite ants
    eggs.burn(msg.sender, 1);
  }

  /// @notice Returns a pseudo random number between 0 and (_range - 1)
  function _random(uint256 _range) internal view returns (uint256) {
    require(_range > 0, '_range cannot be zero');
    return uint256(keccak256(abi.encodePacked(block.number, block.timestamp, msg.sender))) % _range;
  }

  /// @notice When called, the specified Ant hatches a random amount of new eggs, with a certain probability of dying
  /// @dev Function can be called by anyone (new eggs will go to the ant owner). Otherwise please add onlyAntOwner modifier
  function hatchEggs(uint256 _antId) external override {
    if (block.timestamp < antToLastHatchTime[_antId] + hatchPeriod) revert HatchPeriodNotCompleted();
    if (antToOwner[_antId] == address(0)) revert AntDoesntExist();

    address _antOwner = antToOwner[_antId];
    uint256 _newEggsAmount = _random(newEggsRange);
    antToLastHatchTime[_antId] = block.timestamp;
    eggs.mint(_antOwner, _newEggsAmount);
    emit EggsHatched(_newEggsAmount);

    if (probabilityOfDying >= _random(100)) {
      delete antToOwner[_antId];
      _burn(_antId);
      emit AntDead();
    }
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAntsCreated() public view returns (uint256) {
    return antsCreated;
  }

  /// @dev In case needed
  modifier onlyAntOwner(uint256 _antId) {
    if (msg.sender != antToOwner[_antId]) revert Unauthorized();
    _;
  }
}
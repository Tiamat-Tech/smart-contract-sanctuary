import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './ICryptoAnts.sol';
import './IEgg.sol';

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract CryptoAnts is ICryptoAnts, ERC721, Ownable {
  IEgg public immutable eggs;
  uint256[] public allAntsIds;
  mapping(uint256 => uint256) public antReadyTimes;
  mapping(uint256 => uint256) private _antIdToIndex;
  uint256 public antCooldown = 10 minutes;
  uint256 public antsCreated;
  uint256 public eggPrice = 0.01 ether;
  uint8 public eggFee = 60;
  uint256 private _nonce;

  event EggsBought(address indexed _minter, uint256 _amount);
  event AntCreated(address indexed _minter, uint256 indexed _antId);
  event EggsLaid(address indexed _minter, uint256 indexed _antId, uint256 _amount);
  event AntSold(address indexed _burner, uint256 indexed _antId);
  event AntDead(address indexed _owner, uint256 indexed _antId);
  event EggPriceChanged(uint256 _oldEggPrice, uint256 _newEggPrice);
  event EggFeeChanged(uint256 _oldEggFee, uint256 _newEggFee);
  event Received(address indexed _from, uint256 _value);

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
  }

  receive() external payable {
    if (msg.value > 0) {
      emit Received(msg.sender, msg.value);
    }
  }

  fallback() external payable {
    revert('Wrong call to contract');
  }

  function buyEggs() external payable override {
    require(msg.value % eggPrice == 0 && msg.value != 0, 'Wrong ether sent');
    uint256 amount = msg.value / eggPrice;
    eggs.mint(msg.sender, amount);
    emit EggsBought(msg.sender, amount);
  }

  function createAnt() external override {
    eggs.burn(msg.sender, 1);
    uint256 antId = antsCreated++;
    _mint(msg.sender, antId);
    _antIdToIndex[antId] = allAntsIds.length;
    allAntsIds.push(antId);
    emit AntCreated(msg.sender, antId);
  }

  function layEggs(uint256 _antId) external override {
    require(ownerOf(_antId) == msg.sender, 'Unauthorized');
    require(isAntReady(_antId), 'Ant is not ready yet');
    uint256 random = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, _nonce))) % 100;
    uint256 amount = (random / 10) + (random % 10);
    _nonce++;
    eggs.mint(msg.sender, amount);
    emit EggsLaid(msg.sender, _antId, amount);
    if (random > 15 && random <= 85) {
      antReadyTimes[_antId] = block.timestamp + antCooldown;
    } else {
      _deleteAnt(_antId);
      emit AntDead(msg.sender, _antId);
    }
  }

  function sellAnt(uint256 _antId) external override {
    require(ownerOf(_antId) == msg.sender, 'Unauthorized');
    _deleteAnt(_antId);
    emit AntSold(msg.sender, _antId);
    //solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: eggPrice - (eggPrice * eggFee) / 100}('');
    require(success, 'Whoops, this call failed!');
  }

  function setEggPrice(uint256 _eggPrice) external onlyOwner {
    require(_eggPrice != 0, 'Token price cannot be zero');
    emit EggPriceChanged(eggPrice, _eggPrice);
    eggPrice = _eggPrice;
  }

  function setEggFee(uint8 _eggFee) external onlyOwner {
    require(_eggFee <= 100, 'Invalid fee percentage');
    emit EggFeeChanged(eggFee, _eggFee);
    eggFee = _eggFee;
  }

  function getAllAntsIds() external view override returns (uint256[] memory) {
    return allAntsIds;
  }

  function getEtherBalance() external view override returns (uint256) {
    return address(this).balance;
  }

  function isAntReady(uint256 _antId) public view override returns (bool) {
    return antReadyTimes[_antId] <= block.timestamp;
  }

  function _deleteAnt(uint256 _antId) private {
    _burn(_antId);
    allAntsIds[_antIdToIndex[_antId]] = allAntsIds[allAntsIds.length - 1];
    _antIdToIndex[allAntsIds[allAntsIds.length - 1]] = _antIdToIndex[_antId];
    delete _antIdToIndex[_antId];
    allAntsIds.pop();
  }
}
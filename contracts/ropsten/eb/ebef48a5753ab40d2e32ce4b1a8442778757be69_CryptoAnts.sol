import '@openzeppelin/contracts/token/ERC721/ERC721.sol';


import './ICryptoAnts.sol';
import './IEgg.sol';

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract CryptoAnts is ERC721, ICryptoAnts {
  bool public locked = false;
  mapping(uint256 => address) public antToOwner;
  mapping(uint256 => uint256) public antHatchTime; //Interface???
  IEgg public eggs;
  uint256 public eggPrice = 0.1 ether;
  uint256[] public allAntsIds;
  bool public override notLocked = false;
  uint256 public antsCreated = 0;

  constructor() ERC721('Crypto Ants', 'ANTS') {}

  function set(address _eggs) external {
    //Should add reentracy, called once
    eggs = IEgg(_eggs);
  }

  function buyEggs(uint256 _amount) external payable override lock {
    uint256 _eggPrice = eggPrice;
    require(msg.value/_eggPrice == _amount / _eggPrice, 'Not enough eth to mint EGGs');
    uint256 eggsCallerCanBuy = (msg.value / _eggPrice);
    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, eggsCallerCanBuy);
  }

  function setEggPrice(uint256 _price) external {
    eggPrice = _price;
    // emit PriceChange(); //TODO: Fix event
  }

  function _isAntTired(uint256 _antId) internal view returns (bool) {
    return antHatchTime[_antId] + 10 seconds > block.timestamp;
  }

  // To avoid exploiting the determinism of the following code, we should use ChainLinkVRF
  function hatchEggs(uint256 _antId) external {
    require(!_isAntTired(_antId), 'Your ant is tired.');
    require(antToOwner[_antId] == msg.sender, 'This is not the sender ant.');
    eggs.mint(msg.sender, _random() % 20);
    // emit EggsMinted(msg.sender, eggsCallerCanBuy); //TODO: fix event
    if (_random() % 100 > 50) {
      _burn(_antId);
    }
  }

  function sellAnt(uint256 _antId) external {
    require(antToOwner[_antId] == msg.sender, 'Unauthorized');
    // solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: 0.004 ether}('');
    require(success, 'Whoops, this call failed!');
    delete antToOwner[_antId];
    _burn(_antId);
  }

  function createAnt() external {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();
    uint256 _antId = antsCreated++;
    for (uint256 i = 0; i < allAntsIds.length; i++) {
      if (allAntsIds[i] == _antId) revert AlreadyExists();
    }
    _mint(msg.sender, _antId);
    eggs.burn(msg.sender, 1);
    antToOwner[_antId] = msg.sender;
    allAntsIds.push(_antId);
    emit AntCreated();
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAntsCreated() public view returns (uint256) {
    return antsCreated;
  }

  modifier lock() {
    //solhint-disable-next-line
    require(locked == false, 'Sorry, you are not allowed to re-enter here :)');
    locked = true;
    _;
    locked = notLocked;
  }

  function _random() private view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
  }
}
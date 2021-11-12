import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


interface IEgg is IERC20 {
  function mint(address, uint256) external;

  function burn(address, uint256) external;
}

interface ICryptoAnts is IERC721 {
  event EggsBought(address, uint256);
  event EggsMinted(uint256 antId, address ownerId, uint256 amount);
  event EggsBurn(address ownerId, uint256 amount);
  event AntDead(uint256 antId);

  function notLocked() external view returns (bool);

  function buyEggs(uint256) external payable;

  error NoEggs();
  event AntSold();
  error NoZeroAddress();
  event AntCreated();
  error AlreadyExists();
  error WrongEtherSent();
}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract CryptoAnts is ERC721, ICryptoAnts {
  bool public locked = false;
  mapping(uint256 => address) public antToOwner;
  mapping(uint256 => uint256) public antToHatchTime;
  IEgg public immutable eggs;
  uint256 public eggPrice = 0.01 ether;
  uint256[] public allAntsIds;
  bool public override notLocked = false;
  uint256 public antsCreated = 0;
  address public owner;
  uint256 public probOfDeath = 30;

  constructor(address _eggs, address _owner) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
    owner = _owner;
  }

  function updateEggPrice(uint256 _price) public onlyOwner {
    eggPrice = _price;
  }

  function updateProbOfDeath(uint256 _prob) public onlyOwner {
    probOfDeath = _prob;
  }

  function buyEggs(uint256 _amount) external payable override lock {
    uint256 _eggPrice = eggPrice;
    uint256 eggsCallerCanBuy = (msg.value / _eggPrice);
    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, eggsCallerCanBuy);
  }

  function sellAnt(uint256 _antId) external onlyAntOwner(_antId) {
    /* solhint-disable avoid-low-level-calls */
    (bool success, ) = msg.sender.call{value: 0.004 ether}('');
    require(success, 'Whoops, this call failed!');
    _killAnt(_antId);
  }

  function createAnt() external {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();
    uint256 _antId = antsCreated++;
    for (uint256 i = 0; i < allAntsIds.length; i++) {
      if (allAntsIds[i] == _antId) revert AlreadyExists();
    }
    eggs.burn(msg.sender, 1);
    emit EggsBurn(msg.sender, 1);
    _mint(msg.sender, _antId);
    antToOwner[_antId] = msg.sender;
    allAntsIds.push(_antId);
    emit AntCreated();
  }

  function hatch(uint256 _antId) public onlyAntOwner(_antId) enabledToHatch(_antId) {
    if (_rand(100) <= probOfDeath) {
      _killAnt(_antId);
    }

    uint256 maxAmountOfEggsCreated = 10;
    uint256 amount = _rand(maxAmountOfEggsCreated);
    antToHatchTime[_antId] = block.timestamp + 10 minutes;
    eggs.mint(msg.sender, amount);
    emit EggsMinted(_antId, msg.sender, amount);
  }

  function _rand(uint256 _mod) private view returns (uint256) {
    uint256 rand = uint256(keccak256(abi.encodePacked(block.timestamp, antsCreated, eggs.balanceOf(msg.sender))));
    return (rand % _mod) + 1;
  }

  function _killAnt(uint256 _antId) private {
    delete antToOwner[_antId];
    _burn(_antId);
    emit AntDead(_antId);
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  modifier lock() {
    /* solhint-disable reason-string */
    require(locked == false, 'Sorry, you are not allowed to re-enter here :)');
    locked = true;
    _;
    locked = notLocked;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, 'Unauthorized');
    _;
  }

  modifier onlyAntOwner(uint256 _antId) {
    require(antToOwner[_antId] == msg.sender, 'Unauthorized');
    _;
  }

  modifier enabledToHatch(uint256 _antId) {
    /* solhint-disable reason-string */
    require(antToHatchTime[_antId] == 0 || antToHatchTime[_antId] <= block.timestamp, 'You only can hatch once every 10 min');
    _;
  }
}
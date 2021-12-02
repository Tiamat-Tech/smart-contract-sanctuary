import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';



interface IEgg is IERC20 {
  function mint(address, uint256) external;
}

interface ICryptoAnts is IERC721 {
  event EggsBought(address, uint256);

  function notLocked() external view returns (bool);

  function buyEggs(uint256) external payable;

  error Cooldown();
  error NoEggs();
  event AntSold();
  error NoZeroAddress();
  event AntCreated();
  error AlreadyExists();
  error WrongEtherSent();
}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract CryptoAnts is ERC721, ICryptoAnts, Ownable {
  using SafeMath for uint256;
  bool public locked = false;
  mapping(uint256 => address) public antToOwner;
  IEgg public immutable eggs;
  uint256 public eggPrice = 0.01 ether;
  uint256[] public allAntsIds;
  bool public override notLocked = false;
  uint256 public antsCreated = 0;
  bytes32 public constant GOVERNANCE = keccak256('GOVERNANCE');
  address private _owner;
  uint256 public maxEggProduced = 20;
  uint256 public antLifeThreshold = 60;
  uint256 public basicUnit = 1;
  mapping(uint256 => uint256) public next;

  constructor(address _eggs, address _governance) ERC721('Crypto Ants', 'ANTS') Ownable() {
    eggs = IEgg(_eggs);
    _owner = _governance;
  }

  function buyEggs(uint256 _amount) external payable override lock {
    uint256 _eggPrice = eggPrice;
    uint256 eggsCallerCanBuy = (msg.value / _eggPrice);
    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, eggsCallerCanBuy);
  }

  function sellAnt(uint256 _antId) external payable {
    uint256 antPrice;
    if (msg.value == 0) {
      antPrice = 0.004 ether;
    } else {
      antPrice = msg.value;
      // solhint-disable-next-line
      require(antPrice < eggPrice, 'Ant price must be lower than egg price');
    }
    address payable recipient = payable(msg.sender);
    require(antToOwner[_antId] == recipient, 'Unauthorized');
    require(antPrice <= address(this).balance, 'Whoops, this call failed!');
    // solhint-disable-next-line
    (bool success, ) = recipient.call{value: antPrice}('');
    require(success, '');
    delete antToOwner[_antId];
    _burn(_antId);
  }

  function createAnt() external {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();
    uint256 _antId = ++antsCreated;
    for (uint256 i = 0; i < allAntsIds.length; i++) {
      if (allAntsIds[i] == _antId) revert AlreadyExists();
    }
    _mint(msg.sender, _antId);
    antToOwner[_antId] = msg.sender;
    allAntsIds.push(_antId);
    emit AntCreated();
  }

  function generateRandomNumber() public view returns (uint256) {
    uint256 bigNumber = uint256(keccak256(abi.encodePacked(block.number, maxEggProduced, antLifeThreshold)));
    return bigNumber;
  }

  function produceEgg(uint256 _antId) external {
    require(antToOwner[_antId] == msg.sender, 'Unauthorized');
    if (block.timestamp < next[_antId]) revert Cooldown();
    uint256 numberOfEggsProduced = generateRandomNumber().mod(maxEggProduced);
    uint256 healthPoint = generateRandomNumber().mod(100);

    eggs.mint(msg.sender, numberOfEggsProduced);
    if (healthPoint < antLifeThreshold) {
      delete antToOwner[_antId];
      _burn(_antId);
    } else {
      next[_antId] += block.timestamp + 10 minutes;
    }
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAntsCreated() public view returns (uint256) {
    return antsCreated;
  }

  // price must be in ETH
  function setEggPrice(uint256 _eggPrice) external onlyOwner {
    eggPrice = _eggPrice;
  }

  modifier lock() {
    //solhint-disable-next-line
    require(locked == false, 'Sorry, you are not allowed to re-enter here :)');
    locked = true;
    _;
    locked = notLocked;
  }
}
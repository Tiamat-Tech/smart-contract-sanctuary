import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


interface IEgg is IERC20 {
  function mint(address, uint256) external;

  function burn(address, uint256) external;
}

interface ICryptoAnts is IERC721 {
  event EggsBought(address, uint256);
  event AntCreated();
  event AntSold();

  error NoEggs();
  error NoZeroAddress();
  error AlreadyExists();
  error WrongEtherSent();

  function notLocked(uint256) external view returns (bool);

  function buyEggs() external payable;
}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract CryptoAnts is ERC721, ICryptoAnts, Ownable {
  IEgg public immutable eggs;
  uint256 public eggPrice = 0.01 ether;
  uint256 public antsCreated = 0;
  uint256 public antCooldown = 10 minutes;
  uint256 private _randNonce = 0;
  uint256[] public allAntsIds;
  mapping(uint256 => address) public antToOwner;
  mapping(uint256 => uint32) public antReadyTimes;

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
  }

  receive() external payable {}

  function setEggPrice(uint256 _eggPrice) external onlyOwner {
    eggPrice = _eggPrice;
  }

  function buyEggs() external payable override {
    if (msg.sender == address(0)) revert NoZeroAddress();
    uint256 _eggPrice = eggPrice;
    if (msg.value % _eggPrice != 0) revert WrongEtherSent();
    uint256 eggsCallerCanBuy = (msg.value / _eggPrice);
    eggs.mint(msg.sender, eggsCallerCanBuy);
    emit EggsBought(msg.sender, eggsCallerCanBuy);
  }

  function layEggs(uint256 _antId) external lock(_antId) {
    require(antToOwner[_antId] == msg.sender, 'Unauthorized');
    uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _randNonce))) % 100;
    _randNonce++;
    uint256 amount = (random / 10) + (random % 10);
    eggs.mint(msg.sender, amount);
    if (random < 15 || random >= 85) {
      delete antToOwner[_antId];
      _burn(_antId);
    }
  }

  function createAnt() external {
    if (msg.sender == address(0)) revert NoZeroAddress();
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();
    uint256 _antId = ++antsCreated;
    for (uint256 i = 0; i < allAntsIds.length; i++) {
      if (allAntsIds[i] == _antId) revert AlreadyExists();
    }
    eggs.burn(msg.sender, 1);
    _mint(msg.sender, _antId);
    antToOwner[_antId] = msg.sender;
    allAntsIds.push(_antId);
    emit AntCreated();
  }

  function sellAnt(uint256 _antId) external {
    require(antToOwner[_antId] == msg.sender, 'Unauthorized');
    uint256 antBidPrice = (eggPrice * 40) / 100;
    //solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: antBidPrice}('');
    require(success, 'Whoops, this call failed!');
    delete antToOwner[_antId];
    _burn(_antId);
    emit AntSold();
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAllAntsIds() public view returns (uint256[] memory) {
    return allAntsIds;
  }

  function notLocked(uint256 _antId) external view override returns (bool) {
    return antReadyTimes[_antId] <= block.timestamp;
  }

  modifier lock(uint256 _antId) {
    //solhint-disable-next-line
    require(antReadyTimes[_antId] <= block.timestamp, 'Sorry, you are not allowed to re-enter here :)');
    _;
    antReadyTimes[_antId] = uint32(block.timestamp + antCooldown);
  }
}
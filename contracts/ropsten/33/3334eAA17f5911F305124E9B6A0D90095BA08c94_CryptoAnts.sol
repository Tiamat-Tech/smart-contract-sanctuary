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

  function notLocked() external view returns (bool);

  function buyEggs() external payable;
}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract CryptoAnts is ERC721, ICryptoAnts, Ownable {
  IEgg public immutable eggs;
  bool public locked = false;
  bool public override notLocked = false;
  uint256 public eggPrice = 0.01 ether;
  uint256 public antsCreated = 0;
  uint256[] public allAntsIds;
  mapping(uint256 => address) public antToOwner;

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
  }

  function setEggPrice(uint256 _eggPrice) external onlyOwner {
    eggPrice = _eggPrice;
  }

  function buyEggs() external payable override lock {
    if (msg.sender == address(0)) revert NoZeroAddress();
    uint256 _eggPrice = eggPrice;
    if (msg.value % _eggPrice != 0) revert WrongEtherSent();
    uint256 eggsCallerCanBuy = (msg.value / _eggPrice);
    eggs.mint(msg.sender, eggsCallerCanBuy);
    emit EggsBought(msg.sender, eggsCallerCanBuy);
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
    // solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: 0.4 ether * eggPrice}('');
    require(success, 'Whoops, this call failed!');
    delete antToOwner[_antId];
    _burn(_antId);
    emit AntSold();
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
}
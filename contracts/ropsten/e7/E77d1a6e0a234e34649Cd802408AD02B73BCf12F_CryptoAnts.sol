//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


interface IEgg is IERC20 {
  function mint(address, uint256) external;
}

interface ICryptoAnts is IERC721 {
  event EggsBought(address, uint256);

  function notLocked() external view returns (bool);

  function buyEggs(uint256) external payable;

  error NoEggs();
  event AntSold();
  error NoZeroAddress();
  event AntCreated();
  error AlreadyExists();
  error WrongEtherSent();
}



contract CryptoAnts is ERC721, ICryptoAnts {
  bool public locked = false;
  mapping(uint256 => address) public antToOwner;
  IEgg public immutable eggs;
  uint256 public eggPrice = 0.01 ether;
  uint256[] public allAntsIds;
  bool public override notLocked = false;
  uint256 public antsCreated = 0;

  constructor(address _eggs) ERC721('Crypto Hor', 'HOR') {
    eggs = IEgg(_eggs);
  }

  function buyEggs(uint256 _amount) external payable override lock {
    uint256 _eggPrice = eggPrice;
    uint256 eggsCallerCanBuy = (msg.value / _eggPrice);
    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, eggsCallerCanBuy);
  }

  function sellAnt(uint256 _antId) external {
    require(antToOwner[_antId] == msg.sender, 'Unauthorized');
    
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
    
    require(locked == false, 'Sorry, you are not allowed to re-enter here :)');
    locked = true;
    _;
    locked = notLocked;
  }
}
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './IEgg.sol';

interface ICryptoAnts is IERC721 {
  function buyEggs(uint256) external payable;

  function createAnt() external;

  function layEggs(uint256 _antId) external;

  function sellAnt(uint256 _antId) external;

  event AntSold(uint256 antId);
  event AntCreated(uint256 antId);
  event EggsBought(address, uint256);
  event EggsLaid(uint256 eggsLaid);
  event AntDied(uint256 antId);

  error NoEggs();
  error WrongEtherSent();
}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract CryptoAnts is ERC721, ICryptoAnts, Ownable {
  IEgg public immutable eggs;
  uint256 public eggPrice = 0.01 ether;
  uint256 public antSellPrice = 0.004 ether;
  uint256[] public allAntsIds;
  uint256 public antsCreated = 0;
  uint256 public cooldownSeconds = 600;
  uint8 public antDeathProbability = 25; // % chance that ant will die in layEggs
  mapping(uint256 => uint256) public antIdToLastLayTimestamp;

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
  }

  function layEggs(uint256 _antId) external override {
    require(ownerOf(_antId) == msg.sender, 'Unauthorized');
    require(block.timestamp > antIdToLastLayTimestamp[_antId] + cooldownSeconds, 'Wait a bit');

    antIdToLastLayTimestamp[_antId] = block.timestamp;

    uint256 eggsLaid = _pseudoRandom(20, 1111);
    eggs.mint(msg.sender, eggsLaid);
    emit EggsLaid(eggsLaid);

    if (_pseudoRandom(99, 2222) < antDeathProbability) {
      _burn(_antId);
      emit AntDied(_antId);
    }
  }

  function _pseudoRandom(uint256 maxValue, uint256 nonce) private view returns (uint256) {
    uint256 randomValue = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, nonce)));
    return randomValue % (maxValue + 1);
  }

  function buyEggs(uint256 _amount) external payable override {
    if (_amount * eggPrice != msg.value) {
      revert WrongEtherSent();
    }

    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, _amount);
  }

  function createAnt() external override {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();
    eggs.burn(msg.sender, 1);

    uint256 _antId = ++antsCreated;
    _mint(msg.sender, _antId);
    allAntsIds.push(_antId);
    emit AntCreated(_antId);
  }

  function sellAnt(uint256 _antId) external override {
    require(ownerOf(_antId) == msg.sender, 'Unauthorized');

    _burn(_antId);

    // solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: antSellPrice}('');
    require(success, 'Whoops, this call failed!');

    emit AntSold(_antId);
  }

  function setEggPrice(uint256 _eggPrice) external onlyOwner {
    eggPrice = _eggPrice;
  }

  function setAntSellPrice(uint256 _antSellPrice) external onlyOwner {
    antSellPrice = _antSellPrice;
  }

  function setAntDeathProbability(uint8 _percentChance) external onlyOwner {
    antDeathProbability = _percentChance;
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAntsCreated() public view returns (uint256) {
    return antsCreated;
  }
}
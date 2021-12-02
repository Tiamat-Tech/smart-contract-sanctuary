//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './IEgg.sol';
import './ICryptoAnts.sol';


/// @title CryptoAnts
/// @author DrGorilla.eth
/// @notice start by buying an egg, which can be used to create an ant, which
/// in turn can be used to lay a random amount of eggs (but the process can
/// kill the ant too).
/// @dev every ant is an OZ ERC721 and every egg is a 0-decimal OZ ERC20.
/// prices is set via original deployer (stored as governor).

contract CryptoAnts is ERC721, ICryptoAnts {
  uint256 public eggPrice = 0.01 ether;
  uint256 public antPrice = 0.004 ether;
  uint256 public maxEggsLayed = 20;
  uint256 public mortalityRate = 50;
  uint256 private _antsCreated = 0;

  address public governor;

  IEgg public immutable eggs;

  // antId => timestamp
  mapping(uint256 => uint256) public lastLay;

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
    governor = msg.sender;
  }

  /// @notice the correct _amount * eggPrice eth needs to be send with the transaction
  /// @param _amount the amount of eggs
  /// @dev 
  function buyEggs(uint256 _amount) external payable override {
    if (msg.value / eggPrice != _amount) revert WrongEtherSent();

    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, _amount);
  }

  function layEggs(uint256 _antId) external override {
    if (lastLay[_antId] + 600 > block.timestamp) revert LayTooSoon();
    if (ownerOf(_antId) != msg.sender) revert NotYourAnt();

    uint256 randomishAmount = uint256(keccak256(abi.encodePacked(block.coinbase, blockhash(block.number - 1))));
    uint256 randomishMortality = uint256(keccak256(abi.encodePacked(block.coinbase, blockhash(block.number - 2))));
    uint256 amount = randomishAmount % maxEggsLayed;
    bool willDie = randomishMortality % 100 <= mortalityRate;

    if (willDie) {
      _burn(_antId);
      emit AntDead(_antId);
    } else {
      lastLay[_antId] = block.timestamp;
    }

    eggs.mint(msg.sender, amount);
    emit EggLayed(amount);
  }

  function createAnt() external override {
    uint256 _currentId = _antsCreated;

    eggs.burn(msg.sender, 1); //ERC20 _burn will check the balance
    _mint(msg.sender, _currentId);
    lastLay[_currentId] = block.timestamp;
    _antsCreated++;

    emit AntCreated(_currentId);
  }

  function sellAnt(uint256 _antId) external override {
    if (ownerOf(_antId) != msg.sender) revert Unauth();

    _burn(_antId);

    // solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: antPrice}('');
    if (!success) revert WrongEtherSent();

    emit AntSold(_antId);
  }

  function getAntsCreated() external view override returns (uint256) {
    return _antsCreated;
  }

  function setPrices(uint256 _eggPrice, uint256 _antPrice) external override {
    if (msg.sender != governor) revert Unauth();
    eggPrice = _eggPrice;
    antPrice = _antPrice;

    emit PricesChanged(_eggPrice, _antPrice);
  }

  function retrieveEth() external override {
    if (msg.sender != governor) revert Unauth();
    
    // solhint-disable-next-line
    (bool success, ) = payable(msg.sender).call{value: address(this).balance}(new bytes(0));
    if (!success) revert WrongEtherSent();
  }
}
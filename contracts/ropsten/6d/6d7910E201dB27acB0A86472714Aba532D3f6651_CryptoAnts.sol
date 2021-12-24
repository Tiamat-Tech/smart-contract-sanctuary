//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import './interfaces/ICryptoAnts.sol';
import './interfaces/IEgg.sol';

/// @title Crypto Ants contract (inherits ERC721)
/// This contract manages:
///   - Buying eggs
///   - Creating ants
///   - Selling ants
///   - Creating eggs
/// It is ownable by governance
contract CryptoAnts is Ownable, ERC721, ERC721Enumerable, ICryptoAnts, ReentrancyGuard {
  using Address for address payable;
  using Counters for Counters.Counter;

  // Number of eggs needed to create an ant
  uint256 public constant EGGS_TO_ANT = 1;

  // Time needed between eggs creation
  uint256 public constant EGG_CREATION_TIME = 10 minutes;

  // Maximum eggs creation number at a time
  uint256 public constant MAX_EGGS_CREATION_NUMBER = 20;

  // Maximum probability (100%), only for calcs
  uint256 public constant MAX_PROBABILITY = 100;

  // Maximum probability of an ant dying when creating eggs (30%)
  uint256 public constant ANT_DEATH_PROBABILITY = 30;

  // Egg token address
  IEgg public immutable eggs;

  // Price in ether for buying an egg (setted by governance)
  uint256 public eggPrice = 0.01 ether;

  // Price in ether for selling an ant (setted by governance)
  uint256 public antPrice = 0.004 ether;

  // Store the last time an ant created eggs
  // antId => timestamp
  mapping(uint256 => uint256) public lastEggCreation;

  // Track the last ant ID number used
  Counters.Counter private _antsIdCounter;

  /// @param _eggs Egg token address
  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') {
    if (_eggs == address(0)) revert ZeroAddress();
    eggs = IEgg(_eggs);
  }

  //
  // Non-access control functions
  //

  /// @inheritdoc ICryptoAnts
  function buyEggs() external payable override nonReentrant {
    if (msg.value < eggPrice) revert WrongEtherSent();

    uint256 eggsCallerCanBuy = (msg.value / eggPrice);

    emit EggsBought(_msgSender(), eggsCallerCanBuy);

    eggs.mint(_msgSender(), eggsCallerCanBuy);
  }

  /// @inheritdoc ICryptoAnts
  function createAnt() external override nonReentrant {
    if (eggs.balanceOf(_msgSender()) < EGGS_TO_ANT) revert NoEggs();

    eggs.burn(_msgSender(), EGGS_TO_ANT);

    _mintAnt(_msgSender());
  }

  /// @inheritdoc ICryptoAnts
  function sellAnt(uint256 antId) external override nonReentrant {
    if (ownerOf(antId) != _msgSender()) revert Unauthorized();

    _burn(antId);

    emit AntSold(_msgSender(), antId);

    payable(_msgSender()).sendValue(antPrice);
  }

  /// @inheritdoc ICryptoAnts
  function createEggs(uint256 antId) external override nonReentrant {
    if (ownerOf(antId) != _msgSender()) revert Unauthorized();
    if (block.timestamp < lastEggCreation[antId] + EGG_CREATION_TIME) revert WrongEggCreationTime();

    uint256 random = _unsafeRandomNumber();

    uint256 eggsAmount = random % MAX_EGGS_CREATION_NUMBER;
    bool isAntDead = (random % MAX_PROBABILITY) <= ANT_DEATH_PROBABILITY;

    lastEggCreation[antId] = block.timestamp;

    if (isAntDead) {
      _burn(antId);
      emit AntDead(_msgSender(), antId);
    }

    emit EggsCreated(_msgSender(), eggsAmount);
    eggs.mint(_msgSender(), eggsAmount);
  }

  //
  // Private functions
  //

  /// @dev Increment IDs and mint a new ant
  /// @param to address receiving new ant
  function _mintAnt(address to) private {
    uint256 tokenId = _antsIdCounter.current();
    _antsIdCounter.increment();

    emit AntCreated(to, tokenId);

    _safeMint(to, tokenId);
  }

  /// @dev Generates a random number
  /// @dev This random number is unsafe because it is deterministic
  /// @return randomNumber generated from block coinbase, block number and msg sender
  function _unsafeRandomNumber() private view returns (uint256 randomNumber) {
    return uint256(keccak256(abi.encodePacked(block.coinbase, block.number, _msgSender())));
  }

  //
  // Governance functions
  //

  /// @inheritdoc ICryptoAnts
  function setEggPrice(uint256 newPrice) external override onlyOwner {
    if (newPrice == 0) revert WrongPrice();

    eggPrice = newPrice;

    emit EggPriceChanged(newPrice);
  }

  /// @inheritdoc ICryptoAnts
  function setAntPrice(uint256 newPrice) external override onlyOwner {
    if (newPrice == 0) revert WrongPrice();

    antPrice = newPrice;

    emit AntPriceChanged(newPrice);
  }

  /// @inheritdoc ICryptoAnts
  function withdrawBalance() external override onlyOwner {
    uint256 balance = getContractBalance();

    if (balance == 0) revert NoBalance();

    emit BalanceWithdrawn(balance);

    payable(owner()).sendValue(balance);
  }

  //
  // View functions
  //

  /// @inheritdoc ICryptoAnts
  function getContractBalance() public view override returns (uint256 balance) {
    return address(this).balance;
  }

  /// @inheritdoc ICryptoAnts
  function getCurrentAntId() external view override returns (uint256 currentAntId) {
    return _antsIdCounter.current();
  }

  //
  // The following functions are overrides required by Solidity.
  //

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, IERC165) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
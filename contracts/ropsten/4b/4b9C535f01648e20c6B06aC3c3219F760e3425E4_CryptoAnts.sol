//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './interfaces/ICryptoAnts.sol';
import './interfaces/IEgg.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';


contract CryptoAnts is Ownable, ERC721, ICryptoAnts, ReentrancyGuard {
  IEgg public immutable override eggs;
  uint256 public override eggPrice = 0.01 ether;
  uint256 public override antPrice = 0.004 ether;
  uint256 public override antsCreated = 0;
  mapping(uint256 => address) public antToOwner;

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
  }

  /// @notice This external function enables Governance to modify the price of the egg
  function setEggPrice(uint256 _newPrice) external override onlyOwner {
    eggPrice = _newPrice;
  }

  /// @notice This external function enables Governance to modify the price of the ant
  function setAntPrice(uint256 _newPrice) external override onlyOwner {
    antPrice = _newPrice;
  }

  function buyEggs(uint256 _amount) external payable override nonReentrant {
    if (msg.value != eggPrice * _amount) revert WrongEtherSent();
    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, _amount);
  }

  function sellAnt(uint256 _antId) external override nonReentrant {
    /// @dev use of Checks-Effects-Interactions pattern to avoid reentrancy attacks
    if (antToOwner[_antId] != msg.sender) revert Unauthorized();
    if (address(this).balance < antPrice) revert NotEnoughContractBalance();

    delete antToOwner[_antId];
    antsCreated--;
    _burn(_antId);
    emit AntSold();

    // solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: antPrice}('');
    if (!success) revert CallFailed();
  }

  function createAnt() external override {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();

    uint256 _antId = antsCreated++;
    /// @dev All addresses in the mapping are initialized to zero, so we can avoid overwriting by checking the value
    if (antToOwner[_antId] != address(0)) revert AlreadyExists();
    antToOwner[_antId] = msg.sender;

    _mint(msg.sender, _antId);
    emit AntCreated();

    /// @dev Burn the egg used to create the ant, otherwise caller can create infinite ants
    eggs.burn(msg.sender, 1);
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAntsCreated() public view returns (uint256) {
    return antsCreated;
  }
}
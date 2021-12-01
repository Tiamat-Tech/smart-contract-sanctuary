import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './ICryptoAnts.sol';
import './Egg.sol';



//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

/**
 * @dev This contract implemenets Non-Fungible Token that represent ants.
 * Ants can be created with eggs that can be bought in this contract.
 * Ant can later be sold for a less price than the buy price.
 * Ant can also hatch eggs but be aware! they may die doing that.
 */
contract CryptoAnts is ERC721, ICryptoAnts, ReentrancyGuard {
  //Egg ERC20 contract
  IEgg public immutable eggs;

  //current egg price
  uint256 private _eggPrice = 0.01 ether;

  //ant price ratio to calculate the sell price
  uint256 private _antSellPriceRatio = 2;

  //amount of ants created
  uint256 private _antsCreated = 0;

  //governance address which can change the ant price
  address public immutable governanceAddres;

  //map to store the time limit where an ant can hatch eggs again
  mapping(uint256 => uint256) private _antHatchingLimits;

  //nonce to use for pseudo randome number generator
  uint256 private _randNonce = 0;

  //Constants
  uint256 private constant _MAX_HATCHING_EGGS = 21;
  uint256 private constant _DEATCH_HATCHING_PROB = 30;

  constructor(address _eggs, address _governanceAddres) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
    governanceAddres = _governanceAddres;
  }

  /**
   * @dev See {ICryptoAnts-buyEggs}.
   */
  function buyEggs(uint256 _amount) external payable override {
    //solhint-disable-next-line
    require(_amount > 0, 'The amount of eggs to buy should be more than 0');
    require(_amount * _eggPrice <= msg.value, 'Not enough ETH');
    eggs.mint(msg.sender, _amount);
    emit EggsBought(msg.sender, _amount);
  }

  /**
   * @dev See {ICryptoAnts-sellAnt}.
   */
  function sellAnt(uint256 _antId) external override nonReentrant {
    require(ownerOf(_antId) == msg.sender, 'Unauthorized');
    _burn(_antId);
    //solhint-disable-next-line
    (bool success, ) = msg.sender.call{value: getAntPrice()}('');
    require(success, 'Whoops, this call failed!');
    emit AntSold(msg.sender, _antId);
  }

  /**
   * @dev See {ICryptoAnts-createAnt}.
   */
  function createAnt() external override {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();
    eggs.transferFrom(msg.sender, address(this), 1);
    uint256 _antId = _antsCreated++;
    _mint(msg.sender, _antId);
    emit AntCreated(msg.sender, _antId);
  }

  /**
   * @dev See {ICryptoAnts-hatch}.
   */
  function hatch(uint256 _antId) external override {
    require(ownerOf(_antId) == msg.sender, 'Unauthorized');
    //solhint-disable-next-line
    require(
      _antHatchingLimits[_antId] == 0 || block.timestamp <= _antHatchingLimits[_antId],
      'Ants can only hatch once every 10 minutes. Please be patient.'
    );
    _antHatchingLimits[_antId] = block.timestamp + 10 minutes;
    uint256 eggstToHatch = _generatePseudoRandom(_MAX_HATCHING_EGGS);
    eggs.mint(msg.sender, eggstToHatch);
    emit EggsHatched(msg.sender, _antId, eggstToHatch);
    if (_generatePseudoRandom(100) < _DEATCH_HATCHING_PROB) {
      _burn(_antId);
      emit AntDead(_antId);
    }
  }

  function _generatePseudoRandom(uint256 _mod) private returns (uint256) {
    _randNonce++;
    return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _randNonce))) % _mod;
  }

  /**
   * @dev See {ICryptoAnts-getContractBalance}.
   */
  function getContractBalance() public view override returns (uint256) {
    return address(this).balance;
  }

  /**
   * @dev See {ICryptoAnts-getAntsCreated}.
   */
  function getAntsCreated() public view override returns (uint256) {
    return _antsCreated;
  }

  /**
   * @dev See {ICryptoAnts-getEggPrice}.
   */
  function getEggPrice() public view override returns (uint256) {
    return _eggPrice;
  }

  /**
   * @dev See {ICryptoAnts-setEggPrice}.
   */
  function setEggPrice(uint256 _newPrice) external override onlyGovernance {
    _eggPrice = _newPrice;
  }

  /**
   * @dev See {ICryptoAnts-getAntPrice}.
   */
  function getAntPrice() public view override returns (uint256) {
    return _eggPrice / _antSellPriceRatio;
  }

  modifier onlyGovernance() {
    //solhint-disable-next-line
    require(msg.sender == governanceAddres, 'The function can only be called by governance');
    _;
  }
}
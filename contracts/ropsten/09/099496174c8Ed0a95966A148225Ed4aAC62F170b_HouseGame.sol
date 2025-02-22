// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.4;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./IHouseGame.sol";
import "./IAgent.sol";
import "./ICash.sol";
import "./IRandomizer.sol";
import "./HouseGameState.sol";
import "./libraries/TransferHelper.sol";

// solhint-disable-next-line max-states-count
contract HouseGame is Initializable, IHouseGame, HouseGameState, ERC721EnumerableUpgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
  using StringsUpgradeable for uint256;
  using StringsUpgradeable for uint8;

  // House
  uint256 public constant HOUSE_MAX_MINT_PRICE = 0.35 ether;
  uint256 public constant HOUSE_FLOOR_PRICE = 0.07 ether;
  // max number of tokens that can be minted
  uint256 public houseMaxTokens;
  // number of tokens that can be claimed for free
  uint256 public housePaidTokens;
  // number of tokens have been minted so far
  uint16 public houseMinted;
  uint256 public constant HOUSE_PRESALE_PRICE = 0.07 ether;
  uint256 public houseCostMint;

  // Utility building
  uint256 public constant BUILDING_MAX_MINT_PRICE = 3.5 ether;
  uint256 public constant BUILDING_FLOOR_PRICE = 0.7 ether;
  // max number of tokens that can be minted
  uint256 public buildingMaxTokens;
  // number of tokens that can be claimed for free
  uint256 public buildingPaidTokens;
  // number of tokens have been minted so far
  uint16 public buildingMinted;
  uint256 public constant BUILDING_PRESALE_PRICE = 0.7 ether;

  uint16 public minted;

  uint256 public constant IMAGE_NUMBER = 256;

  // mapping from tokenId to a struct containing the token's traits
  mapping(uint256 => HouseBuilding) public tokenTraits;

  // list of probabilities for each trait type
  uint8[][18] public rarities;
  // list of aliases for Walker's Alias algorithm
  uint8[][18] public aliases;

  // tokenURI
  string public baseURI;
  string public baseExtension;

  // reference to the Barn for choosing random House thieves
  IAgent public agent;
  // reference to $CASH for burning on mint
  ICASH public cash;

  IRandomizer public randomizer;

  HouseInfo[] public houseInfoList;

  struct Whitelist {
    bool isWhitelisted;
    uint16 houseNumMinted;
    uint16 buildingNumMinted;
  }
  mapping(address => Whitelist) private _whitelistAddresses;
  //public sale
  uint256 private housePriceDecrementAmt;
  uint256 private buildingPriceDecrementAmt;
  uint256 private timeToDecrementPrice;
  uint256 private startedTime;
  bool public hasPublicSaleStarted;

  /** 
   * instantiates contract and rarity tables
   */
  function initialize(address _cash, address _randomizer, string memory _initBaseURI, uint256 _houseMaxTokens, uint256 _buildingMaxTokens) external initializer { 
    __ERC721_init("House Game", "HGAME");
    OwnableUpgradeable.__Ownable_init();
    PausableUpgradeable.__Pausable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    cash = ICASH(_cash);
    randomizer = IRandomizer(_randomizer);

    setBaseURI(_initBaseURI);

    houseMaxTokens = _houseMaxTokens;
    buildingMaxTokens = _buildingMaxTokens;
    housePaidTokens = _houseMaxTokens / 2;
    buildingPaidTokens = _buildingMaxTokens;

    houseInfoList.push(HouseInfo(Model.TREE_HOUSE, 12 ether, 5));
    houseInfoList.push(HouseInfo(Model.TRAILER_HOUSE, 14 ether, 5));
    houseInfoList.push(HouseInfo(Model.CABIN, 18 ether, 5));
    houseInfoList.push(HouseInfo(Model.ONE_STORY_HOUSE, 20 ether, 10));
    houseInfoList.push(HouseInfo(Model.TWO_STORY_HOUSE, 26 ether, 10));
    houseInfoList.push(HouseInfo(Model.MANSION, 30 ether, 15));
    houseInfoList.push(HouseInfo(Model.PALACE, 37 ether, 15));

    // I know this looks weird but it saves users gas by making lookup O(1)
    // A.J. Walker's Alias Algorithm
    // house
    // model
    rarities[0] = [255, 146, 174, 31, 179, 72, 18];
    aliases[0] = [0, 0, 0, 1, 1, 2, 3];

    // set value
    baseExtension = ".json";
    housePriceDecrementAmt = 0.023334 ether;
    buildingPriceDecrementAmt = 0.23334 ether;
    timeToDecrementPrice = 5 minutes;
  }

  /** EXTERNAL */

  /** 
   * mint a token
   */
  function mintHouse(uint256 amount, bool stake) external payable whenNotPaused {
    require(tx.origin == _msgSender(), "Only EOA"); // solhint-disable-line avoid-tx-origin
    require(amount > 0, "Invalid mint amount");
    require(houseMinted + amount <= houseMaxTokens, "All tokens minted");
    if (houseMinted < housePaidTokens) {
      require(houseMinted + amount <= housePaidTokens, "All tokens on-sale already sold");
      if(hasPublicSaleStarted) {
        require(msg.value >= amount * currentPriceToMint(true), "Invalid payment amount");
      } else {
        require(amount * HOUSE_PRESALE_PRICE == msg.value, "Invalid payment amount");
        require(_whitelistAddresses[_msgSender()].isWhitelisted, "Not on whitelist");
        require(_whitelistAddresses[_msgSender()].houseNumMinted + amount <= 3, "too many house mints");
        require(_whitelistAddresses[_msgSender()].buildingNumMinted == 0, "can not mint house");
        _whitelistAddresses[_msgSender()].houseNumMinted += uint16(amount);
      }
    } else {
      require(msg.value == 0, "Invalid value");
    }

    uint16[] memory tokenIds = stake ? new uint16[](amount) : new uint16[](0);
    uint256 totalCashCost = 0;
    uint256 seed;
    for (uint i = 0; i < amount; i++) {
      houseMinted++;
      minted++;
      seed = randomizer.random(minted);
      generate(minted, true, seed);
      if (stake) {
        _safeMint(address(agent), minted);
        tokenIds[i] = minted;
      } else {
        _safeMint(_msgSender(), minted);
      }
      totalCashCost += mintCost(houseMinted);
    }
    
    if (totalCashCost > 0) cash.burn(_msgSender(), totalCashCost);
    if (stake) agent.addManyToAgentAndPack(_msgSender(), tokenIds);
  }

  function mintBuilding(uint256 amount, bool stake) external payable whenNotPaused {
    require(tx.origin == _msgSender(), "Only EOA"); // solhint-disable-line avoid-tx-origin
    require(amount > 0, "Invalid mint amount");
    require(buildingMinted + amount <= buildingMaxTokens, "All tokens minted");
    if (buildingMinted < buildingPaidTokens) {
      require(buildingMinted + amount <= buildingPaidTokens, "All tokens on-sale already sold");
      if(hasPublicSaleStarted) {
        require(msg.value >= amount * currentPriceToMint(false), "Invalid payment amount");
      } else {
        require(amount * BUILDING_PRESALE_PRICE == msg.value, "Invalid payment amount");
        require(_whitelistAddresses[_msgSender()].isWhitelisted, "Not on whitelist");
        require(_whitelistAddresses[_msgSender()].buildingNumMinted + amount <= 1, "too many building mints");
        require(_whitelistAddresses[_msgSender()].houseNumMinted == 0, "can not mint building");
        _whitelistAddresses[_msgSender()].buildingNumMinted += uint16(amount);
      }
    } else {
      require(msg.value == 0, "Invalid value");
    }

    uint16[] memory tokenIds = stake ? new uint16[](amount) : new uint16[](0);
    uint256 seed;
    for (uint i = 0; i < amount; i++) {
      buildingMinted++;
      minted++;
      seed = randomizer.random(minted);
      generate(minted, false, seed);
      if (stake) {
        _safeMint(address(agent), minted);
        tokenIds[i] = minted;
      } else {
        _safeMint(_msgSender(), minted);
      }
    }
    if (stake) agent.addManyToAgentAndPack(_msgSender(), tokenIds);
  }

  function currentPriceToMint(bool isHouse) public view returns(uint256) {
    uint256 numDecrements = (block.timestamp - startedTime) / timeToDecrementPrice; // solhint-disable-line not-rely-on-time
    uint256 decrementAmt = ((isHouse ? housePriceDecrementAmt : buildingPriceDecrementAmt) * numDecrements);
    uint256 maxPrice = getMaxPrice(isHouse);
    uint256 floorPrice = getFloorPrice(isHouse);
    if(decrementAmt > maxPrice || maxPrice - decrementAmt <= floorPrice) {
      return floorPrice;
    }
    uint256 adjPrice = maxPrice - decrementAmt;
    return adjPrice;
  }

  function getMaxPrice(bool isHouse) private pure returns(uint256) {
    if(isHouse)
    {
      return HOUSE_MAX_MINT_PRICE;
    }
    return BUILDING_MAX_MINT_PRICE;
  }

  function getFloorPrice(bool isHouse) private pure returns(uint256) {
    if(isHouse)
    {
      return HOUSE_FLOOR_PRICE;
    }
    return BUILDING_FLOOR_PRICE;
  }

  function addToWhitelist(address[] calldata addressesToAdd) public onlyOwner {
    for (uint256 i = 0; i < addressesToAdd.length; i++) {
      _whitelistAddresses[addressesToAdd[i]] = Whitelist(true, 0, 0);
    }
  }

  function isWhitelisted(address _address) public view returns(bool) {
        return _whitelistAddresses[_address].isWhitelisted;
  }

  function setPublicSaleStart(bool started) external onlyOwner {
    hasPublicSaleStarted = started;
    if(hasPublicSaleStarted) {
      startedTime = block.timestamp; // solhint-disable-line not-rely-on-time
    }
  }

  /** 
   * the first 50% are paid in ETH
   * @param tokenId the ID to check the cost of to mint
   * @return the cost of the given token ID
   */
  function mintCost(uint256 tokenId) public view returns (uint256) {
    if (tokenId <= housePaidTokens) return 0;
    return houseCostMint;
  }

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
    // Hardcode the Barn's approval so that users don't have to waste gas approving
    if (_msgSender() != address(agent))
      require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved"); // solhint-disable-line reason-string
    _transfer(from, to, tokenId);
  }

  /** INTERNAL */

  /**
   * generates traits for a specific token, checking to make sure it's unique
   * @param tokenId the id of the token to generate traits for
   * @param seed a pseudorandom 256 bit number to derive traits from
   * @return t - a struct of traits for the given token ID
   */
  function generate(uint256 tokenId, bool isHouse, uint256 seed) internal returns (HouseBuilding memory t) {
    t = selectTraits(seed, isHouse);
    tokenTraits[tokenId] = t;
  }

  /**
   * uses A.J. Walker's Alias algorithm for O(1) rarity table lookup
   * ensuring O(1) instead of O(n) reduces mint cost by more than 50%
   * probability & alias tables are generated off-chain beforehand
   * @param seed portion of the 256 bit seed to remove trait correlation
   * @param traitType the trait type to select a trait for 
   * @return the ID of the randomly selected trait
   */
  function selectTrait(uint16 seed, uint8 traitType) internal view returns (uint8) {
    uint8 trait = uint8(seed) % uint8(rarities[traitType].length);
    if (seed >> 8 < rarities[traitType][trait]) return trait;
    return aliases[traitType][trait];
  }

  /**
   * selects the species and all of its traits based on the seed value
   * @param seed a pseudorandom 256 bit number to derive traits from
   * @return t -  a struct of randomly selected traits
   */
  function selectTraits(uint256 seed, bool isHouse) internal view returns (HouseBuilding memory t) {    
    seed >>= 16;
    t.isHouse = isHouse;
    t.model = isHouse ? selectTrait(uint16(seed & 0xFFFF), 0) : 7;

    seed >>= 16;
    t.imageId = (uint8(seed & 0xFFFF) % IMAGE_NUMBER) + 1;
  }

  /** READ */

  function getTokenTraits(uint256 tokenId) external view override returns (HouseBuilding memory) {
    return tokenTraits[tokenId];
  }

  function getHousePaidTokens() external view override returns (uint256) {
    return housePaidTokens;
  }

  function getBuildingPaidTokens() external view override returns (uint256) {
    return buildingPaidTokens;
  }

  function getHouseInfo(uint256 tokenId) public view returns (HouseInfo memory _houseInfo) {
    HouseBuilding memory _houseBuilding = tokenTraits[tokenId];
    if(_houseBuilding.isHouse)
    {
      _houseInfo = houseInfoList[_houseBuilding.model];
    }
  }

  function getIncomePerDay(uint256 tokenId) external view override returns (uint256 _incomePerDay) {
    HouseInfo memory _houseInfo = getHouseInfo(tokenId);
    _incomePerDay = _houseInfo.incomePerDay;
  }

  function getPropertyDamage(uint256 tokenId) external view override returns (uint256 _propertyDamage) {
    HouseInfo memory _houseInfo = getHouseInfo(tokenId);
    _propertyDamage = _houseInfo.propertyDamage;
  }

  /** ADMIN */
   
  function setContracts(address _randomizer, address _agent) external onlyOwner {
    require(_randomizer != address(0) && _agent != address(0), "Invalid contract address");
    randomizer = IRandomizer(_randomizer);
    agent = IAgent(_agent);
  }

  function setCostMintHouse(uint256 _houseCostMint) external onlyOwner {
    require(_houseCostMint > 0, "Invalid value");
    houseCostMint = _houseCostMint;
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  /**
   * allows owner to withdraw funds from minting
   */
  function withdraw() external onlyOwner nonReentrant {
    TransferHelper.safeTransfer(owner(), address(this).balance);
  }

  /**
   * updates the number of tokens for sale
   */
  function setHousePaidTokens(uint256 _paidTokens) external onlyOwner {
    housePaidTokens = _paidTokens;
  }

  function setBuildingPaidTokens(uint256 _paidTokens) external onlyOwner {
    buildingPaidTokens = _paidTokens;
  }

  /**
   * enables owner to pause / unpause minting
   */
  function setPaused(bool _paused) external onlyOwner {
    if (_paused) _pause();
    else _unpause();
  }

  /** RENDER */

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token"); // solhint-disable-line reason-string
    HouseBuilding memory _houseBuilding = tokenTraits[tokenId];
    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _houseBuilding.model.toString(), "/", _houseBuilding.imageId.toString(), baseExtension))
        : "";
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }
}
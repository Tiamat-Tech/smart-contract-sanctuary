//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableMap.sol";
import "./../utils/Validator.sol";


contract HeroAlliance is ERC721, Ownable, Validator {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    struct Hero {
        string name;
        uint genes;
        uint equipment;
        uint minValue;
        uint8 level;
    }

    // The total supply of heroes
    uint private constant _TOTAL_HERO = 10000;

    // The array containing all available heroes
    Hero[] public _heroes;

    // The mapping from hero's name to its availability
    mapping(string => bool) private _reservedNames;

    // The timestamp when the sale will begin
    uint private _saleStartTime;

    // The initial price at the start of the sale
    uint private _initialPrice;

    // The percentage of total value traded adds to hero floor price
    uint public _floorPricePercentage = 10;

    constructor(uint saleStartTime, uint initialPrice) ERC721("Hero Alliance", "HRS") {
        _setBaseURI("https://cryptoheroes.art/hero/id/");
        _saleStartTime = saleStartTime;
        _initialPrice = initialPrice;
    }

    modifier onlyOwnerOf(uint heroId) {
        require(ownerOf(heroId) == _msgSender());
        _;
    }

    /**
     * @dev Gets current hero Price
     */
    function getCurrentPrice() public view returns (uint256) {
        uint currentSupply = _heroes.length;

        require(block.timestamp >= _saleStartTime, "Sale has not started");
        require(currentSupply < _TOTAL_HERO, "Sale has already ended");

        if (currentSupply >= 9000) {
            return _initialPrice * 5;
        }  else if (currentSupply >= 8000) {
            return _initialPrice * 45 / 10;
        }  else if (currentSupply >= 7000) {
            return _initialPrice * 4;
        } else if (currentSupply >= 6000) {
            return _initialPrice * 35 / 10;
        } else if (currentSupply >= 5000) {
            return _initialPrice * 3;
        } else if (currentSupply >= 4000) {
            return _initialPrice * 25 / 10;
        } else if (currentSupply >= 3000) {
            return _initialPrice * 2;
        } else if (currentSupply >= 2000) {
            return _initialPrice * 15 / 10;
        } else {
            return _initialPrice;
        }
    }

    /**
     * @notice Anyone can claim a hero with certain amount of ETH.
     */
    function claimHero() external payable {
        uint currentPrice = getCurrentPrice();

        require(_heroes.length < _TOTAL_HERO, "HeroAlliance: all heroes have been claimed");
        require(msg.value == currentPrice, "HeroAlliance: ether value sent is not correct");

        uint minValue = currentPrice * _floorPricePercentage / 100;
        uint heroId = _createHero(minValue);
        _safeMint(_msgSender(), heroId);

        (bool contractTransfer,) = payable(address(this)).call{ value: minValue }("");
        require(contractTransfer, "HeroAlliance: transfer fund to contract failed");

        (bool ownerTransfer,) = payable(owner()).call{ value: currentPrice * (100 - _floorPricePercentage) / 100 }("");
        require(ownerTransfer, "HeroAlliance: transfer fund to owner failed");
    }

    /**
     * @notice Gets hero's attributes by its ID.
     */
    function getHeroAttributes(uint heroId) external view returns (
        string memory name,
        uint genes,
        uint equipment,
        uint minValue,
        uint8 level
    ) {
        Hero memory hero = _heroes[heroId];

        name = hero.name;
        genes = hero.genes;
        equipment = hero.equipment;
        minValue = hero.minValue;
        level = hero.level;
    }

    /**
     * @notice Renames a hero by its ID.
     */
    function changeHeroName(uint heroId, string memory newName) external onlyOwnerOf(heroId) {
        Hero storage hero = _heroes[heroId];

        require(_validateName(newName) == true, "HeroAlliance:m not a valid nae");
        require(sha256(bytes(hero.name)) != sha256(bytes(newName)), "HeroAlliance: same name detected");
        require(_reservedNames[newName] == false, "HeroAlliance: name already exists");

        // If already named, de-reserve current name
        if (bytes(hero.name).length > 0) {
            _reservedNames[hero.name] = false;
        }

        hero.name = newName;
        _reservedNames[newName] = true;
    }

    /**
     * @notice Burns a hero to claim its floor price. *Not financial advice: DONT DO THAT*
     */
    function sacrificeHero(uint heroId) external payable onlyOwnerOf(heroId) {
        Hero storage hero = _heroes[heroId];
        uint amount = hero.minValue;

        hero.minValue = 0;
        _burn(heroId);

        (bool success, ) = _msgSender().call{ value : amount }("");
        require(success, "HeroAlliance: transfer fund to sender failed");
    }

    /**
     * @notice Creates a hero
     */
    function _createHero(uint minValue) internal returns (uint id) {
        // TODO: get hero genes here
        _heroes.push(Hero("", 0, 1000100010001000100010001000100010001, minValue, 1));
        id = _heroes.length - 1;
    }
}
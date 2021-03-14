//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ICryptoHero.sol";
import "../interfaces/IEquipment.sol";

contract CryptoHero is ICryptoHero, ERC721, Ownable {
    // The total supply of heroes.
    uint public constant TOTAL_HERO = 10000;

    // The maximum heroes representing a single token symbol.
    uint public constant MAX_HERO_PER_SYMBOL = 5;

    // 1 Basis Point = 0.01%.
    uint public constant BPS = 10000;

    // Timestamp when the sale will begin.
    uint public constant SALE_START_TIMESTAMP = 1611846000;

    // Time after which heroes are randomized and allotted
    uint public constant REVEAL_TIMESTAMP = SALE_START_TIMESTAMP + (86400 * 14);

    uint256 public constant MAX_NFT_SUPPLY = 10000;

    uint256 public startingIndexBlock;

    uint256 public startingIndex;

    // Contract for interacting with ERC1155 items.
    IEquipment public equipmentContract;

    // Base URI for fetching metadata.
    string public baseURI;

    // BPS adds to hero's floor price.
    uint public floorPriceInBps = 200;

    // BPS adds to development fund.
    uint public marketFeeInBps = 22;

    // Mapping from hero to currently on sale price.
    mapping(uint => uint) public heroesOnSale;

    // Mapping from hero to all addresses with offer.
    mapping(uint => mapping(address => uint)) public heroesWithOffers;

    // Mapping from hero's name to its availability.
    mapping(string => bool) public reservedNames;

    // Mapping from token symbol to a list of heroes.
    mapping(string => uint[]) public symbolToHeroes;

    // Mapping from hero to its information
    Hero[] private _heroes;

    // The initial price at the start of the sale.
    uint private _initialSalePrice;

    constructor(
        IEquipment equipmentAddress_,
        string memory baseURI_,
        uint initialSalePrice_
    ) ERC721("CryptoHero", "HERO") {
        equipmentContract = IEquipment(equipmentAddress_);
        baseURI = baseURI_;
        _initialSalePrice = initialSalePrice_;
    }

    modifier onlyOwnerOf(uint heroId) {
        require(ownerOf(heroId) == _msgSender());
        _;
    }

    function setEquipmentContract(IEquipment equipmentContract_) external onlyOwner {
        equipmentContract = equipmentContract_;
    }

    function setFloorPricePercentage(uint value) external onlyOwner {
        floorPriceInBps = value;
    }

    function setMarketFeePercentage(uint value) external onlyOwner {
        marketFeeInBps = value;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /**
     * @dev Finalize starting index
     */
    function finalizeStartingIndex() external {
        require(startingIndex == 0, "CryptoHero: Starting index is already set");
        require(startingIndexBlock != 0, "CryptoHero: Starting index block must be set");

        startingIndex = uint(blockhash(startingIndexBlock)) % TOTAL_HERO;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number - startingIndexBlock > 255) {
            startingIndex = uint(blockhash(block.number - 1)) % TOTAL_HERO;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex + 1;
        }
    }

    function getCurrentSalePrice() public view returns (uint) {
        uint currentSupply = _heroes.length;

        require(block.timestamp >= SALE_START_TIMESTAMP, "CryptoHero: sale has not started");
        require(currentSupply < TOTAL_HERO, "CryptoHero: sale has already ended");

        if (currentSupply >= 9000) {
            return _initialSalePrice * 39 / 10;
        }  else if (currentSupply >= 8000) {
            return _initialSalePrice * 37 / 10;
        }  else if (currentSupply >= 7000) {
            return _initialSalePrice * 34 / 10;
        } else if (currentSupply >= 6000) {
            return _initialSalePrice * 3;
        } else if (currentSupply >= 5000) {
            return _initialSalePrice * 28 / 10;
        } else if (currentSupply >= 4000) {
            return _initialSalePrice * 25 / 10;
        } else if (currentSupply >= 3000) {
            return _initialSalePrice * 2;
        } else if (currentSupply >= 2000) {
            return _initialSalePrice * 15 / 10;
        } else {
            return _initialSalePrice;
        }
    }

    /**
     * @dev See {ICryptoHero-getHero}.
     */
    function getHero(uint heroId) external view override returns (
        string memory name,
        string memory symbol,
        bool isAlive,
        uint8 level,
        uint floorPrice,
        uint[8] memory equipment
    ) {
        Hero memory hero = _heroes[heroId];

        name = hero.name;
        symbol = hero.symbol;
        level = hero.level;
        isAlive = _exists(heroId);
        floorPrice = hero.floorPrice;
        equipment = [hero.weaponMain, hero.weaponSub, hero.headgear, hero.armor, hero.footwear, hero.pants, hero.glove, hero.pet];
    }

    /**
     * @dev See {ICryptoHero-addFloorPriceToHero}.
     */
    function addFloorPriceToHero(uint heroId) external override payable {
        require(msg.value > 0, "CryptoHero: no value sent");
        require(_heroes[heroId].floorPrice < 100 ether, "CryptoHero: cannot add more");

        _heroes[heroId].floorPrice += msg.value;
    }

    /**
     * @dev See {ICryptoHero-claimHero}.
     */
    function claimHero() external override payable {
        uint currentPrice = getCurrentSalePrice();

        require(_heroes.length < TOTAL_HERO, "CryptoHero: all heroes have been claimed");
        require(msg.value == currentPrice, "CryptoHero: sent value does not match");

        uint floorPrice = currentPrice * floorPriceInBps / BPS;
        uint heroId = _createHero(floorPrice);
        _safeMint(_msgSender(), heroId);

        (bool transferResult,) = payable(owner()).call{value: currentPrice - floorPrice}("");
        require(transferResult, "CryptoHero: transfer to development fund failed");

        if (startingIndexBlock == 0 && (_heroes.length == TOTAL_HERO || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }
    }

    /**
     * @dev See {ICryptoHero-changeHeroName}.
     */
    function changeHeroName(uint heroId, string memory newName) external override onlyOwnerOf(heroId) {
        require(_validateStr(newName, false) == true, "CryptoHero: name is invalid");
        require(sha256(bytes(_heroes[heroId].name)) != sha256(bytes(newName)), "CryptoHero: same name detected");
        require(reservedNames[newName] == false, "CryptoHero: name already exists");

        Hero storage hero = _heroes[heroId];

        // If already named, de-reserve current name
        if (bytes(hero.name).length > 0) {
            reservedNames[hero.name] = false;
        }

        hero.name = newName;
        reservedNames[newName] = true;
    }

    /**
     * @dev See {ICryptoHero-attachSymbolToHero}.
     */
    function attachSymbolToHero(uint heroId, string memory symbol) external override onlyOwnerOf(heroId) {
        require(_validateStr(symbol, true) == true, "CryptoHero: symbol is invalid");
        require((bytes(_heroes[heroId].symbol).length == 0), "CryptoHero: symbol already attached");
        require(symbolToHeroes[symbol].length < MAX_HERO_PER_SYMBOL, "CryptoHero: symbol has been taken");

        Hero storage hero = _heroes[heroId];

        hero.symbol = symbol;
        symbolToHeroes[symbol].push(heroId);
    }

    /**
     * @dev See {ICryptoHero-equipItems}.
     */
    function equipItems(uint heroId, uint[] memory itemIds, EquipmentSlot[] memory slots) external override onlyOwnerOf(heroId) {
        require(itemIds.length == slots.length, "CryptoHero: itemIds and slots length mismatch");

        Hero storage hero = _heroes[heroId];

        for (uint8 i = 0; i < itemIds.length; i++) {
            if (slots[i] == EquipmentSlot.WEAPON_MAIN) {
                hero.weaponMain = itemIds[i];
            } else if (slots[i] == EquipmentSlot.WEAPON_SUB) {
                hero.weaponSub = itemIds[i];
            } else if (slots[i] == EquipmentSlot.HEADGEAR) {
                hero.headgear = itemIds[i];
            } else if (slots[i] == EquipmentSlot.ARMOR) {
                hero.armor = itemIds[i];
            } else if (slots[i] == EquipmentSlot.FOOTWEAR) {
                hero.footwear = itemIds[i];
            } else if (slots[i] == EquipmentSlot.PANTS) {
                hero.pants = itemIds[i];
            } else if (slots[i] == EquipmentSlot.GLOVE) {
                hero.glove = itemIds[i];
            } else if (slots[i] == EquipmentSlot.PET) {
                hero.pet = itemIds[i];
            }
        }

        equipmentContract.burnItems(_msgSender(), itemIds);
    }

    /**
     * @dev See {ICryptoHero-removeItems}.
     */
    function removeItems(uint heroId, EquipmentSlot[] memory slots) external override onlyOwnerOf(heroId) {
        uint[] memory itemIds;
        Hero storage hero = _heroes[heroId];

        for (uint8 i = 0; i < slots.length; i++) {
            if (slots[i] == EquipmentSlot.WEAPON_MAIN) {
                if (hero.weaponMain == 0) continue;
                itemIds[i] = hero.weaponMain;
                hero.weaponMain = 0;
            } else if (slots[i] == EquipmentSlot.WEAPON_SUB) {
                if (hero.weaponSub == 0) continue;
                itemIds[i] = hero.weaponSub;
                hero.weaponSub = 0;
            } else if (slots[i] == EquipmentSlot.HEADGEAR) {
                if (hero.headgear == 0) continue;
                itemIds[i] = hero.headgear;
                hero.headgear = 0;
            } else if (slots[i] == EquipmentSlot.ARMOR) {
                if (hero.armor == 0) continue;
                itemIds[i] = hero.armor;
                hero.armor = 0;
            } else if (slots[i] == EquipmentSlot.FOOTWEAR) {
                if (hero.footwear == 0) continue;
                itemIds[i] = hero.footwear;
                hero.footwear = 0;
            } else if (slots[i] == EquipmentSlot.PANTS) {
                if (hero.pants == 0) continue;
                itemIds[i] = hero.pants;
                hero.pants = 0;
            } else if (slots[i] == EquipmentSlot.GLOVE) {
                if (hero.glove == 0) continue;
                itemIds[i] = hero.glove;
                hero.glove = 0;
            } else if (slots[i] == EquipmentSlot.PET) {
                if (hero.pet == 0) continue;
                itemIds[i] = hero.pet;
                hero.pet = 0;
            }
        }

        equipmentContract.mintItems(_msgSender(), itemIds);
    }

    /**
     * @dev See {ICryptoHero-sacrificeHero}.
     */
    function sacrificeHero(uint heroId) external override onlyOwnerOf(heroId) {
        Hero storage hero = _heroes[heroId];
        uint amount = hero.floorPrice;

        hero.floorPrice = 0;
        _burn(heroId);

        (bool success, ) = _msgSender().call{ value: amount }("");
        require(success, "CryptoHero: refund failed");
    }

    /**
     * @dev See {ICryptoHero-list}.
     */
    function list(uint heroId, uint price) external override onlyOwnerOf(heroId) {
        require(price >= _heroes[heroId].floorPrice, "CryptoHero: price cannot be under hero's floor price");

        heroesOnSale[heroId] = price;
    }

    /**
     * @dev See {ICryptoHero-buy}.
     */
    function buy(uint heroId) external override payable {
        uint price = heroesOnSale[heroId];

        require(price > 0, "CryptoHero: given hero is not on sale");
        require(msg.value == price, "CryptoHero: sent value does not match");

        _makeTransaction(heroId, _msgSender(), ownerOf(heroId), price);
    }

    /**
     * @dev See {ICryptoHero-offer}.
     */
    function offer(uint heroId) external override payable {
        require(_msgSender() != ownerOf(heroId), "CryptoHero: owner cannot offer");
        require(msg.value >= _heroes[heroId].floorPrice, "CryptoHero: offer cannot be under hero's floor price");

        heroesWithOffers[heroId][_msgSender()] = msg.value;
    }

    /**
     * @dev See {ICryptoHero-takeOffer}.
     */
    function takeOffer(uint heroId, address offerAddr, uint minPrice) external override onlyOwnerOf(heroId) {
        uint offerValue = heroesWithOffers[heroId][_msgSender()];

        require(offerValue >= _heroes[heroId].floorPrice, "CryptoHero: cannot take offer under hero's floor price");
        require(offerValue >= minPrice, "CryptoHero: offer value must be at least equal to min price");

        heroesWithOffers[heroId][offerAddr] = 0;

        _makeTransaction(heroId, offerAddr, _msgSender(), offerValue);
    }

    /**
     * @dev See {ICryptoHero-cancelOffer}.
     */
    function cancelOffer(uint heroId) external override {
        address sender = _msgSender();
        uint offerValue = heroesWithOffers[heroId][sender];

        require(offerValue > 0, "CryptoHero: no offer found");

        heroesWithOffers[heroId][sender] = 0;

        (bool success,) = payable(sender).call{value: offerValue}("");
        require(success, "CryptoHero: transfer fund failed");
    }

    function _makeTransaction(uint heroId, address buyer, address seller, uint price) private {
        uint floorPrice = price * floorPriceInBps / BPS;
        uint marketFee = price * marketFeeInBps / BPS;

        heroesOnSale[heroId] = 0;
        _heroes[heroId].floorPrice += floorPrice;

        (bool transferToSeller,) = payable(seller).call{value: price - (floorPrice + marketFee)}("");
        require(transferToSeller, "CryptoHero: transfer fund to seller failed");

        (bool transferToTreasury,) = payable(owner()).call{value: marketFee}("");
        require(transferToTreasury, "CryptoHero: transfer fund to treasury failed");

        _transfer(seller, buyer, heroId);
    }

    function _createHero(uint floorPrice) private returns (uint) {
        uint nextId = _heroes.length + 1;

        _heroes[nextId] = Hero("", "", 1, floorPrice, 0, 0, 0, 0, 0, 0, 0, 0);

        return nextId;
    }

    /**
     * @dev Check if the name string is valid (Alphanumeric and spaces without leading or trailing space)
     */
    function _validateStr(string memory str, bool isSymbol) internal pure returns (bool) {
        bytes memory b = bytes(str);
        if (b.length < 1) return false;
        if (b.length > 20) return false;
        if (isSymbol && b.length > 5) return false;

        // Leading space
        if (b[0] == 0x20) return false;

        // Trailing space
        if (b[b.length - 1] == 0x20) return false;

        bytes1 lastChar = b[0];

        for (uint i; i < b.length; i++) {
            bytes1 char = b[i];

            // Cannot contain continuous spaces
            if (char == 0x20 && lastChar == 0x20) return false;

            if (
                !(char >= 0x30 && char <= 0x39) && //9-0
                !(char >= 0x41 && char <= 0x5A) && //A-Z
                !(char >= 0x61 && char <= 0x7A) && //a-z
                !(char == 0x20) //space
            ) {
                return false;
            }

            lastChar = char;
        }

        return true;
    }
}
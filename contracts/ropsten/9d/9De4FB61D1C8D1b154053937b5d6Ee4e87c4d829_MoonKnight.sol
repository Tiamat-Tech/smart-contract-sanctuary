//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMoonKnight.sol";
import "../equipment/IEquipment.sol";
import "../pet/IPet.sol";
import "../utils/AcceptedToken.sol";

contract MoonKnight is IMoonKnight, ERC721Enumerable, AcceptedToken {
    using EnumerableSet for EnumerableSet.UintSet;

    // This is the provenance record of all MoonKnight artworks in existence.
    // TODO: need to be updated later.
    string public constant MOON_KNIGHT_PROVENANCE = "";

    // Maximum knights representing a single token symbol.
    uint private constant MAX_KNIGHT_PER_SYMBOL = 5;

    // 1 Basis Point = 0.01%.
    uint private constant BPS = 10000;

    // Contract for interacting with equipment.
    IEquipment public equipmentContract;

    // Contract for interacting with pet.
    IPet public petContract;

    uint public startingIndex;
    uint public floorPriceInBps = 200;
    uint public marketFeeInBps = 22;
    uint public serviceFeeInToken = 1e20;

    // Maximum value that can be added manually.
    uint public floorPriceCap = 100 ether;

    // Mapping from knight to currently adopted pet.
    mapping(uint => uint) public knightsWithPet;

    // Mapping from knight to currently on sale price.
    mapping(uint => uint) public knightsOnSale;

    // Mapping from knight to all addresses with offer.
    mapping(uint => mapping(address => uint)) public knightsWithOffers;

    // Mapping from knight's name to its availability.
    mapping(string => bool) public reservedNames;

    // Mapping from token symbol to a list of knights.
    mapping(string => uint[]) public symbolToKnights;

    // Skills learned by a Knight
    mapping(uint => EnumerableSet.UintSet) private _knightSkills;

    // Total supply of moon knights on presale phase.
    uint private _totalSaleKnights = 20000;

    Knight[] private _knights;
    uint private _salePrice;
    uint private _revealTime;
    string private _uri;

    constructor(
        IEquipment equipmentAddress,
        IERC20 tokenAddress,
        string memory baseURI,
        uint salePrice,
        uint revealTime
    ) ERC721("MoonKnight", "KNIGHT") AcceptedToken(tokenAddress) {
        equipmentContract = equipmentAddress;
        _uri = baseURI;
        _salePrice = salePrice;
        _revealTime = revealTime;
    }

    modifier onlyKnightOwner(uint knightId) {
        require(ownerOf(knightId) == msg.sender, "MoonKnight: not knight owner");
        _;
    }

    function setEquipmentContract(IEquipment equipmentAddress) external onlyOwner {
        require(address(equipmentAddress) != address(0), "MoonKnight: zero address");
        equipmentContract = equipmentAddress;
    }

    function setPetContract(IPet petAddress) external onlyOwner {
        require(address(petAddress) != address(0), "MoonKnight: zero address");
        petContract = petAddress;
    }

    function setFloorPriceAndMarketFeeInBps(uint floorPrice, uint marketFee) external onlyOwner {
        require(floorPrice + marketFee <= BPS, "MoonKnight: invalid total BPS");

        floorPriceInBps = floorPrice;
        marketFeeInBps = marketFee;
    }

    function setFloorPriceCap(uint value) external onlyOwner {
        floorPriceCap = value;
    }

    function setServiceFee(uint value) external onlyOwner {
        serviceFeeInToken = value;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _uri = baseURI;
    }

    function getKnightsByOwner(address owner) external view override returns (uint[] memory) {
        uint count = balanceOf(owner);
        uint[] memory ids = new uint[](count);

        for (uint i = 0; i < count; i++) {
            ids[i] = tokenOfOwnerByIndex(owner, i);
        }

        return ids;
    }

    function getKnight(uint knightId) external view override returns (
        string memory name,
        string memory symbol,
        bool isAlive,
        uint level,
        uint floorPrice,
        uint[] memory skills,
        uint[9] memory equipment
    ) {
        Knight memory knight = _knights[knightId];

        uint skillCount = _knightSkills[knightId].length();
        uint[] memory skillIds = new uint[](skillCount);
        for (uint i = 0; i < skillCount; i++) {
            skillIds[i] = _knightSkills[knightId].at(i);
        }

        name = knight.name;
        symbol = knight.symbol;
        level = knight.level;
        isAlive = _exists(knightId);
        floorPrice = knight.floorPrice;
        skills = skillIds;
        equipment = [
            knight.mainWeapon,
            knight.subWeapon,
            knight.headgear,
            knight.armor,
            knight.footwear,
            knight.pants,
            knight.gloves,
            knight.mount,
            knight.troop
        ];
    }

    function claimMoonKnight(uint amount) external override payable {
        require(amount > 0 && amount <= 10, "MoonKnight: amount out of range");
        require(balanceOf(msg.sender) + amount <= 10, "MoonKnight: 10 at most");
        require(_knights.length + amount <= _totalSaleKnights, "MoonKnight: sold out");
        require(msg.value == _salePrice * amount, "MoonKnight: incorrect value");

        uint floorPrice = _salePrice * 1000 / BPS;

        for (uint i = 0; i < amount; i++) {
            uint knightId = _createKnight(floorPrice);
            _safeMint(msg.sender, knightId);
        }

        (bool isSuccess,) = owner().call{value: _salePrice - floorPrice}("");
        require(isSuccess, "MoonKnight: transfer failed");

        if (startingIndex == 0 && (_knights.length == _totalSaleKnights || block.timestamp >= _revealTime)) {
            _finalizeStartingIndex();
        }
    }

    function changeKnightName(uint knightId, string memory newName) external override onlyKnightOwner(knightId) {
        require(acceptedToken.balanceOf(msg.sender) >= serviceFeeInToken, "MoonKnight: insufficient token balance");
        require(_validateStr(newName, false) == true, "MoonKnight: invalid name");
        require(reservedNames[newName] == false, "MoonKnight: name already exists");

        Knight storage knight = _knights[knightId];

        // If already named, de-reserve current name
        if (bytes(knight.name).length > 0) {
            reservedNames[knight.name] = false;
        }

        knight.name = newName;
        reservedNames[newName] = true;

        bool isSuccess = acceptedToken.transferFrom(msg.sender, owner(), serviceFeeInToken);
        require(isSuccess, "MoonKnight: transfer token failed");

        emit NameChanged(knightId, newName);
    }

    function attachSymbolToKnight(uint knightId, string memory symbol) external override onlyKnightOwner(knightId) {
        require(acceptedToken.balanceOf(msg.sender) >= serviceFeeInToken, "MoonKnight: insufficient token balance");
        require(_validateStr(symbol, true) == true, "MoonKnight: invalid symbol");
        require((bytes(_knights[knightId].symbol).length == 0), "MoonKnight: symbol already attached");
        require(symbolToKnights[symbol].length < MAX_KNIGHT_PER_SYMBOL, "MoonKnight: symbol taken");

        Knight storage knight = _knights[knightId];

        knight.symbol = symbol;
        symbolToKnights[symbol].push(knightId);

        bool isSuccess = acceptedToken.transferFrom(msg.sender, owner(), serviceFeeInToken);
        require(isSuccess, "MoonKnight: transfer token failed");

        emit SymbolChanged(knightId, symbol);
    }

    function equipItems(uint knightId, uint[] memory itemIds) external override onlyKnightOwner(knightId) {
        _setKnightEquipment(knightId, itemIds, false);

        equipmentContract.putItemsIntoStorage(msg.sender, itemIds);

        emit ItemsEquipped(knightId, itemIds);
    }

    function removeItems(uint knightId, uint[] memory itemIds) external override onlyKnightOwner(knightId) {
        _setKnightEquipment(knightId, itemIds, true);

        equipmentContract.returnItems(msg.sender, itemIds);

        emit ItemsUnequipped(knightId, itemIds);
    }

    function addFloorPriceToKnight(uint knightId) external override payable {
        uint increasedAmount = msg.value;
        uint feeInToken = serviceFeeInToken * (increasedAmount / 1e18);
        Knight storage knight = _knights[knightId];

        require(increasedAmount > 0, "MoonKnight: no value sent");
        require(knight.floorPrice < floorPriceCap, "MoonKnight: cannot add more");
        require(acceptedToken.balanceOf(msg.sender) >= feeInToken, "MoonKnight: insufficient token balance");

        uint newPrice = knight.floorPrice + increasedAmount;
        knight.floorPrice = newPrice;

        bool isSuccess = acceptedToken.transferFrom(msg.sender, owner(), feeInToken);
        require(isSuccess, "MoonKnight: transfer token failed");

        emit KnightPriceIncreased(knightId, newPrice, increasedAmount);
    }

    function sacrificeKnight(uint knightId) external override onlyKnightOwner(knightId) {
        Knight storage knight = _knights[knightId];
        uint amount = knight.floorPrice;

        knight.floorPrice = 0;
        _burn(knightId);

        (bool isSuccess,) = msg.sender.call{value: amount}("");
        require(isSuccess, "MoonKnight: refund failed");
    }

    function list(uint knightId, uint price) external override onlyKnightOwner(knightId) {
        require(price >= _knights[knightId].floorPrice, "MoonKnight: under floor price");

        knightsOnSale[knightId] = price;

        emit KnightListed(knightId, price);
    }

    function delist(uint knightId) external override onlyKnightOwner(knightId) {
        require(knightsOnSale[knightId] > 0, "MoonKnight: not listed");

        knightsOnSale[knightId] = 0;

        emit KnightDelisted(knightId);
    }

    function buy(uint knightId) external override payable {
        uint price = knightsOnSale[knightId];
        address seller = ownerOf(knightId);

        require(price > 0, "MoonKnight: not on sale");
        require(msg.value == price, "MoonKnight: incorrect value");

        _makeTransaction(knightId, msg.sender, seller, price);

        emit KnightBought(knightId, msg.sender, seller, price);
    }

    function offer(uint knightId) external override payable {
        require(msg.sender != ownerOf(knightId), "MoonKnight: owner cannot offer");
        require(msg.value >= _knights[knightId].floorPrice, "MoonKnight: under floor price");

        knightsWithOffers[knightId][msg.sender] = msg.value;

        emit KnightOffered(knightId, msg.sender, msg.value);
    }

    function takeOffer(uint knightId, address buyerAddr, uint minPrice) external override onlyKnightOwner(knightId) {
        uint offerValue = knightsWithOffers[knightId][buyerAddr];

        require(offerValue >= _knights[knightId].floorPrice, "MoonKnight: under floor price");
        require(offerValue >= minPrice, "MoonKnight: less than min price");

        knightsWithOffers[knightId][buyerAddr] = 0;

        _makeTransaction(knightId, buyerAddr, msg.sender, offerValue);

        emit KnightBought(knightId, buyerAddr, msg.sender, offerValue);
    }

    function cancelOffer(uint knightId) external override {
        address sender = msg.sender;
        uint offerValue = knightsWithOffers[knightId][sender];

        require(offerValue > 0, "MoonKnight: no offer found");

        knightsWithOffers[knightId][sender] = 0;

        (bool success,) = sender.call{value: offerValue}("");
        require(success, "MoonKnight: transfer failed");

        emit KnightOfferCanceled(knightId, sender);
    }

    function learnSkill(uint knightId, uint skillId) external override {
        IEquipment.ItemType itemType = equipmentContract.getItemType(skillId);
        EnumerableSet.UintSet storage skills = _knightSkills[knightId];

        require(itemType == IEquipment.ItemType.SKILL_BOOK, "MoonKnight: invalid skill book");
        require(!skills.contains(skillId), "MoonKnight: already learned");

        skills.add(skillId);

        uint[] memory skillIds = new uint[](1);
        skillIds[0] = skillId;
        equipmentContract.putItemsIntoStorage(msg.sender, skillIds);

        emit SkillLearned(knightId, skillId);
    }

    function adoptPet(uint knightId, uint petId) external override onlyKnightOwner(knightId) {
        require(address(petContract) != address(0), "MoonKnight: invalid pet contract");
        require(petContract.ownerOf(petId) == msg.sender, "MoonKnight: not pet owner");

        knightsWithPet[knightId] = petId;
        petContract.bindPet(petId);

        emit PetAdopted(knightId, petId);
    }

    function abandonPet(uint knightId) external override onlyKnightOwner(knightId) {
        uint petId = knightsWithPet[knightId];

        require(petId != 0, "MoonKnight: no pet");

        knightsWithPet[knightId] = 0;
        petContract.releasePet(petId);

        emit PetReleased(knightId, petId);
    }

    function generateKnight(address account) external override onlyOperator {
        uint knightId = _createKnight(0);
        _safeMint(account, knightId);
    }

    function levelUp(uint knightId, uint amount) external override onlyOperator {
        require(amount > 0, "MoonKnight: invalid amount");

        Knight storage knight = _knights[knightId];
        uint newLevel = knight.level + amount;

        knight.level = newLevel;

        emit KnightLeveledUp(knightId, newLevel, amount);
    }

    function finalizeDuelResult(
        uint winningKnightId,
        uint losingKnightId,
        uint penaltyInBps
    ) external override onlyOperator {
        Knight storage losingKnight = _knights[losingKnightId];
        uint penaltyAmount = losingKnight.floorPrice * penaltyInBps / BPS;

        _knights[winningKnightId].floorPrice += penaltyAmount;
        losingKnight.floorPrice -= penaltyAmount;

        emit DuelConcluded(winningKnightId, losingKnightId, penaltyAmount);
    }

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function _makeTransaction(uint knightId, address buyer, address seller, uint price) private {
        Knight storage knight = _knights[knightId];
        uint floorPrice = price * floorPriceInBps / BPS;
        uint marketFee = price * marketFeeInBps / BPS;
        uint newPrice = knight.floorPrice + floorPrice;

        knightsOnSale[knightId] = 0;
        knight.floorPrice = newPrice;

        (bool transferToSeller,) = seller.call{value: price - (floorPrice + marketFee)}("");
        require(transferToSeller, "MoonKnight: transfer to seller failed");

        (bool isSuccess,) = owner().call{value: marketFee}("");
        require(isSuccess, "MoonKnight: transfer to treasury failed");

        _transfer(seller, buyer, knightId);

        emit KnightPriceIncreased(knightId, newPrice, floorPrice);
    }

    function _createKnight(uint floorPrice) private returns (uint) {
        _knights.push(Knight("", "", 1, floorPrice, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        uint knightId = _knights.length - 1;
        emit KnightCreated(knightId, floorPrice);
        return knightId;
    }

    function _setKnightEquipment(uint knightId, uint[] memory itemIds, bool isRemove) private {
        require(itemIds.length > 0, "MoonKnight: no item");

        Knight storage knight = _knights[knightId];
        bool[] memory itemSet = new bool[](9);

        for (uint i = 0; i < itemIds.length; i++) {
            uint itemId = itemIds[i];
            uint updatedItemId = isRemove ? 0 : itemId;
            IEquipment.ItemType itemType = equipmentContract.getItemType(itemId);

            require(itemId != 0, "MoonKnight: invalid id");
            require(itemType != IEquipment.ItemType.SKILL_BOOK, "MoonKnight: cannot equip skill book");
            require(!itemSet[uint(itemType)], "MoonKnight: duplicate item type");

            if (itemType == IEquipment.ItemType.MAIN_WEAPON) {
                require(isRemove ? knight.mainWeapon == itemId : knight.mainWeapon == 0, "MoonKnight : invalid mainWeapon");
                knight.mainWeapon = updatedItemId;
                itemSet[uint(IEquipment.ItemType.MAIN_WEAPON)] = true;
            } else if (itemType == IEquipment.ItemType.SUB_WEAPON) {
                require(isRemove ? knight.subWeapon == itemId : knight.subWeapon == 0, "MoonKnight : invalid subWeapon");
                knight.subWeapon = updatedItemId;
                itemSet[uint(IEquipment.ItemType.SUB_WEAPON)] = true;
            } else if (itemType == IEquipment.ItemType.HEADGEAR) {
                require(isRemove ? knight.headgear == itemId : knight.headgear == 0, "MoonKnight : invalid headgear");
                knight.headgear = updatedItemId;
                itemSet[uint(IEquipment.ItemType.HEADGEAR)] = true;
            } else if (itemType == IEquipment.ItemType.ARMOR) {
                require(isRemove ? knight.armor == itemId : knight.armor == 0, "MoonKnight : invalid armor");
                knight.armor = updatedItemId;
                itemSet[uint(IEquipment.ItemType.ARMOR)] = true;
            } else if (itemType == IEquipment.ItemType.FOOTWEAR) {
                require(isRemove ? knight.footwear == itemId : knight.footwear == 0, "MoonKnight : invalid footwear");
                knight.footwear = updatedItemId;
                itemSet[uint(IEquipment.ItemType.FOOTWEAR)] = true;
            } else if (itemType == IEquipment.ItemType.PANTS) {
                require(isRemove ? knight.pants == itemId : knight.pants == 0, "MoonKnight : invalid pants");
                knight.pants = updatedItemId;
                itemSet[uint(IEquipment.ItemType.PANTS)] = true;
            } else if (itemType == IEquipment.ItemType.GLOVES) {
                require(isRemove ? knight.gloves == itemId : knight.gloves == 0, "MoonKnight : invalid gloves");
                knight.gloves = updatedItemId;
                itemSet[uint(IEquipment.ItemType.GLOVES)] = true;
            } else if (itemType == IEquipment.ItemType.MOUNT) {
                require(isRemove ? knight.mount == itemId : knight.mount == 0, "MoonKnight : invalid mount");
                knight.mount = updatedItemId;
                itemSet[uint(IEquipment.ItemType.MOUNT)] = true;
            } else if (itemType == IEquipment.ItemType.TROOP) {
                require(isRemove ? knight.troop == itemId : knight.troop == 0, "MoonKnight : invalid troop");
                knight.troop = updatedItemId;
                itemSet[uint(IEquipment.ItemType.TROOP)] = true;
            }
        }
    }

    function _finalizeStartingIndex() private {
        startingIndex = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % _totalSaleKnights;
        if (startingIndex == 0) startingIndex = startingIndex + 1;
        emit StartingIndexFinalized(startingIndex);
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

            // Symbol cannot contain space
            if (isSymbol && char == 0x20) return false;

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
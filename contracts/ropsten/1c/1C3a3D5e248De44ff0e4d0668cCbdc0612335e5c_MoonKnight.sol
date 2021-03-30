//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMoonKnight.sol";
import "../equipment/IEquipment.sol";

contract MoonKnight is IMoonKnight, ERC721, Ownable {
    // The total supply of moon knights.
    uint public constant TOTAL_KNIGHT = 10000;

    // The maximum knights representing a single token symbol.
    uint public constant MAX_KNIGHT_PER_SYMBOL = 5;

    // 1 Basis Point = 0.01%.
    uint public constant BPS = 10000;

    // Contract for interacting with ERC1155 items.
    IEquipment public equipmentContract;

    uint public startingIndex;
    uint public floorPriceInBps = 200;
    uint public marketFeeInBps = 22;

    // Maximum value that can be added manually.
    uint public floorPriceCap = 100 ether;

    // Mapping from knight to currently on sale price.
    mapping(uint => uint) public knightsOnSale;

    // Mapping from knight to all addresses with offer.
    mapping(uint => mapping(address => uint)) public knightsWithOffers;

    // Mapping from knight's name to its availability.
    mapping(string => bool) public reservedNames;

    // Mapping from token symbol to a list of knights.
    mapping(string => uint[]) public symbolToKnights;

    Knight[] private _knights;
    uint private _salePrice;
    uint private _revealTime;
    string private _uri;

    constructor(
        IEquipment equipmentAddress,
        string memory baseURI,
        uint salePrice,
        uint revealTime
    ) ERC721("MoonKnight", "KNT") {
        equipmentContract = equipmentAddress;
        _uri = baseURI;
        _salePrice = salePrice;
        _revealTime = revealTime;
    }

    modifier onlyOwnerOf(uint knightId) {
        require(ownerOf(knightId) == msg.sender, "MoonKnight: not owner of the knight");
        _;
    }

    function setEquipmentContract(IEquipment equipmentAddress) external onlyOwner {
        require(address(equipmentAddress) != address(0), "MoonKnight: set to zero address");

        equipmentContract = equipmentAddress;
    }

    function setFloorPriceAndMarketFeeInBps(uint floorPrice, uint marketFee) external onlyOwner {
        require(floorPrice + marketFee <= BPS, "MoonKnight: invalid total BPS");

        floorPriceInBps = floorPrice;
        marketFeeInBps = marketFee;
    }

    function setFloorPriceCap(uint value) external onlyOwner {
        floorPriceCap = value;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _uri = baseURI;
    }

    /**
     * @dev See {IMoonKnight-getMoonKnight}.
     */
    function getMoonKnight(uint knightId) external view override returns (
        string memory name,
        string memory symbol,
        bool isAlive,
        uint8 level,
        uint floorPrice,
        uint[8] memory equipment
    ) {
        Knight memory knight = _knights[knightId];

        name = knight.name;
        symbol = knight.symbol;
        level = knight.level;
        isAlive = _exists(knightId);
        floorPrice = knight.floorPrice;
        equipment = [
            knight.mainWeapon,
            knight.subWeapon,
            knight.headgear,
            knight.armor,
            knight.footwear,
            knight.pants,
            knight.gloves,
            knight.pet
        ];
    }

    /**
     * @dev See {IMoonKnight-claimMoonKnight}.
     */
    function claimMoonKnight() external override payable {
        require(_knights.length < TOTAL_KNIGHT, "MoonKnight: sold out");
        require(msg.value == _salePrice, "MoonKnight: incorrect value");

        uint floorPrice = _salePrice * 1000 / BPS;
        uint knightId = _createKnight(floorPrice);
        _safeMint(msg.sender, knightId);

        (bool transferResult,) = payable(owner()).call{value: _salePrice - floorPrice}("");
        require(transferResult, "MoonKnight: transfer failed");

        if (startingIndex == 0 && (_knights.length == TOTAL_KNIGHT || block.timestamp >= _revealTime)) {
            _finalizeStartingIndex();
        }
    }

    /**
     * @dev See {IMoonKnight-changeKnightName}.
     */
    function changeKnightName(uint knightId, string memory newName) external override onlyOwnerOf(knightId) {
        require(_validateStr(newName, false) == true, "MoonKnight: invalid name");
        require(reservedNames[newName] == false, "MoonKnight: name already exists");

        Knight storage knight = _knights[knightId];

        // If already named, de-reserve current name
        if (bytes(knight.name).length > 0) {
            reservedNames[knight.name] = false;
        }

        knight.name = newName;
        reservedNames[newName] = true;
    }

    /**
     * @dev See {IMoonKnight-attachSymbolToKnight}.
     */
    function attachSymbolToKnight(uint knightId, string memory symbol) external override onlyOwnerOf(knightId) {
        require(_validateStr(symbol, true) == true, "MoonKnight: invalid symbol");
        require((bytes(_knights[knightId].symbol).length == 0), "MoonKnight: symbol already attached");
        require(symbolToKnights[symbol].length < MAX_KNIGHT_PER_SYMBOL, "MoonKnight: symbol taken");

        Knight storage knight = _knights[knightId];

        knight.symbol = symbol;
        symbolToKnights[symbol].push(knightId);
    }

    /**
     * @dev See {IMoonKnight-equipItems}.
     */
    function equipItems(uint knightId, uint[] memory itemIds) external override onlyOwnerOf(knightId) {
        _setKnightEquipment(knightId, itemIds, false);

        equipmentContract.takeItemsAway(msg.sender, itemIds);
    }

    /**
     * @dev See {IMoonKnight-removeItems}.
     */
    function removeItems(uint knightId, uint[] memory itemIds) external override onlyOwnerOf(knightId) {
        _setKnightEquipment(knightId, itemIds, true);

        equipmentContract.returnItems(msg.sender, itemIds);
    }

    /**
     * @dev See {IMoonKnight-addFloorPriceToKnight}.
     */
    function addFloorPriceToKnight(uint knightId) external override payable {
        require(msg.value > 0, "MoonKnight: no value sent");
        require(_knights[knightId].floorPrice < floorPriceCap, "MoonKnight: cannot add more");

        _knights[knightId].floorPrice += msg.value;
    }

    /**
     * @dev See {IMoonKnight-sacrificeKnight}.
     */
    function sacrificeKnight(uint knightId) external override onlyOwnerOf(knightId) {
        Knight storage knight = _knights[knightId];
        uint amount = knight.floorPrice;

        knight.floorPrice = 0;
        _burn(knightId);

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "MoonKnight: refund failed");
    }

    /**
     * @dev See {IMoonKnight-list}.
     */
    function list(uint knightId, uint price) external override onlyOwnerOf(knightId) {
        require(price >= _knights[knightId].floorPrice, "MoonKnight: under floor price");

        knightsOnSale[knightId] = price;

        emit KnightListed(knightId, price);
    }

    /**
     * @dev See {IMoonKnight-buy}.
     */
    function buy(uint knightId) external override payable {
        uint price = knightsOnSale[knightId];

        require(price > 0, "MoonKnight: not on sale");
        require(msg.value == price, "MoonKnight: incorrect value");

        address seller = ownerOf(knightId);

        _makeTransaction(knightId, msg.sender, seller, price);

        emit KnightBought(knightId, msg.sender, seller, price);
    }

    /**
     * @dev See {IMoonKnight-offer}.
     */
    function offer(uint knightId) external override payable {
        require(msg.sender != ownerOf(knightId), "MoonKnight: owner cannot offer");
        require(msg.value >= _knights[knightId].floorPrice, "MoonKnight: under floor price");

        knightsWithOffers[knightId][msg.sender] = msg.value;

        emit KnightOffered(knightId, msg.sender, msg.value);
    }

    /**
     * @dev See {IMoonKnight-takeOffer}.
     */
    function takeOffer(uint knightId, address buyerAddr, uint minPrice) external override onlyOwnerOf(knightId) {
        uint offerValue = knightsWithOffers[knightId][buyerAddr];

        require(offerValue >= _knights[knightId].floorPrice, "MoonKnight: under floor price");
        require(offerValue >= minPrice, "MoonKnight: less than min price");

        knightsWithOffers[knightId][buyerAddr] = 0;

        _makeTransaction(knightId, buyerAddr, msg.sender, offerValue);

        emit KnightBought(knightId, buyerAddr, msg.sender, offerValue);
    }

    /**
     * @dev See {IMoonKnight-cancelOffer}.
     */
    function cancelOffer(uint knightId) external override {
        address sender = msg.sender;
        uint offerValue = knightsWithOffers[knightId][sender];

        require(offerValue > 0, "MoonKnight: no offer found");

        knightsWithOffers[knightId][sender] = 0;

        (bool success,) = payable(sender).call{value: offerValue}("");
        require(success, "MoonKnight: transfer failed");

        emit KnightOfferCanceled(knightId, sender);
    }

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function _makeTransaction(uint knightId, address buyer, address seller, uint price) private {
        uint floorPrice = price * floorPriceInBps / BPS;
        uint marketFee = price * marketFeeInBps / BPS;

        knightsOnSale[knightId] = 0;
        _knights[knightId].floorPrice += floorPrice;

        (bool transferToSeller,) = payable(seller).call{value: price - (floorPrice + marketFee)}("");
        require(transferToSeller, "MoonKnight: transfer to seller failed");

        (bool transferToTreasury,) = payable(owner()).call{value: marketFee}("");
        require(transferToTreasury, "MoonKnight: transfer to treasury failed");

        _transfer(seller, buyer, knightId);
    }

    function _createKnight(uint floorPrice) private returns (uint) {
        _knights.push(Knight("", "", 1, floorPrice, 0, 0, 0, 0, 0, 0, 0, 0));
        return _knights.length - 1;
    }

    function _setKnightEquipment(uint knightId, uint[] memory itemIds, bool isRemove) private {
        require(itemIds.length <= 8, "MoonKnight: incorrect ids length");

        Knight storage knight = _knights[knightId];
        bool[8] memory itemSet = [false, false, false, false, false, false, false, false];

        for (uint i = 0; i < itemIds.length; i++) {
            IEquipment.EquipmentSlot itemSlot = equipmentContract.getItemSlot(itemIds[i]);

            require(!itemSet[uint(itemSlot)], "MoonKnight: duplicate items");

            uint itemId = itemIds[i];
            uint setItemId = isRemove ? 0 : itemId;

            if (itemSlot == IEquipment.EquipmentSlot.MAIN_WEAPON) {
                require(!isRemove || knight.mainWeapon == itemId, "MoonKnight: invalid mainWeapon id");
                knight.mainWeapon = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.MAIN_WEAPON)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.SUB_WEAPON) {
                require(!isRemove || knight.subWeapon == itemId, "MoonKnight: invalid subWeapon id");
                knight.subWeapon = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.SUB_WEAPON)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.HEADGEAR) {
                require(!isRemove || knight.headgear == itemId, "MoonKnight: invalid headgear id");
                knight.headgear = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.HEADGEAR)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.ARMOR) {
                require(!isRemove || knight.armor == itemId, "MoonKnight: invalid armor id");
                knight.armor = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.ARMOR)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.FOOTWEAR) {
                require(!isRemove || knight.footwear == itemId, "MoonKnight: invalid footwear id");
                knight.footwear = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.FOOTWEAR)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.PANTS) {
                require(!isRemove || knight.pants == itemId, "MoonKnight: invalid pants id");
                knight.pants = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.PANTS)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.GLOVES) {
                require(!isRemove || knight.gloves == itemId, "MoonKnight: invalid gloves id");
                knight.gloves = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.GLOVES)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.PET) {
                require(!isRemove || knight.pet == itemId, "MoonKnight: invalid pet id");
                knight.pet = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.PET)] = true;
            }
        }
    }

    function _finalizeStartingIndex() private {
        startingIndex = uint(blockhash(block.number)) % TOTAL_KNIGHT;
        if (startingIndex == 0) startingIndex = startingIndex + 1;
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
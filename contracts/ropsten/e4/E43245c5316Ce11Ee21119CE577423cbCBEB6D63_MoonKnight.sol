//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMoonKnight.sol";
import "../equipment/IEquipment.sol";
import "../utils/PermissionGroup.sol";
import "../utils/TokenWithdrawable.sol";

contract MoonKnight is IMoonKnight, ERC721Enumerable, PermissionGroup, TokenWithdrawable {
    // Maximum knights representing a single token symbol.
    uint public constant MAX_KNIGHT_PER_SYMBOL = 5;

    // 1 Basis Point = 0.01%.
    uint public constant BPS = 10000;

    // Contract for interacting with ERC1155 items.
    IEquipment public equipmentContract;

    // Token to be used in the ecosystem.
    IERC20 public acceptedToken;

    uint public startingIndex;
    uint public floorPriceInBps = 200;
    uint public marketFeeInBps = 22;
    uint public serviceFeeInToken = 1e20;

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

    // Total supply of moon knights on presale phase.
    uint private _totalSaleKnights = 10000;

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
    ) ERC721("MoonKnight", "KNT") {
        equipmentContract = equipmentAddress;
        acceptedToken = tokenAddress;
        _uri = baseURI;
        _salePrice = salePrice;
        _revealTime = revealTime;
    }

    modifier onlyOwnerOf(uint knightId) {
        require(ownerOf(knightId) == msg.sender, "MoonKnight: not knight owner");
        _;
    }

    function setAcceptedTokenContract(IERC20 tokenAddress) external onlyOwner {
        require(address(tokenAddress) != address(0), "MoonKnight: zero address");
        acceptedToken = tokenAddress;
    }

    function setEquipmentContract(IEquipment equipmentAddress) external onlyOwner {
        require(address(equipmentAddress) != address(0), "MoonKnight: zero address");
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

    function changeKnightName(uint knightId, string memory newName) external override onlyOwnerOf(knightId) {
        require(_validateStr(newName, false) == true, "MoonKnight: invalid name");
        require(reservedNames[newName] == false, "MoonKnight: name already exists");
        require(acceptedToken.balanceOf(msg.sender) >= serviceFeeInToken, "MoonKnight: insufficient token balance");

        Knight storage knight = _knights[knightId];

        // If already named, de-reserve current name
        if (bytes(knight.name).length > 0) {
            reservedNames[knight.name] = false;
        }

        knight.name = newName;
        reservedNames[newName] = true;

        bool isSuccess = acceptedToken.transferFrom(msg.sender, owner(), serviceFeeInToken);
        require(isSuccess, "MoonKnight: transfer token failed");
    }

    function attachSymbolToKnight(uint knightId, string memory symbol) external override onlyOwnerOf(knightId) {
        require(_validateStr(symbol, true) == true, "MoonKnight: invalid symbol");
        require((bytes(_knights[knightId].symbol).length == 0), "MoonKnight: symbol already attached");
        require(symbolToKnights[symbol].length < MAX_KNIGHT_PER_SYMBOL, "MoonKnight: symbol taken");
        require(acceptedToken.balanceOf(msg.sender) >= serviceFeeInToken, "MoonKnight: insufficient token balance");

        Knight storage knight = _knights[knightId];

        knight.symbol = symbol;
        symbolToKnights[symbol].push(knightId);

        bool isSuccess = acceptedToken.transferFrom(msg.sender, owner(), serviceFeeInToken);
        require(isSuccess, "MoonKnight: transfer token failed");
    }

    function equipItems(uint knightId, uint[] memory itemIds) external override onlyOwnerOf(knightId) {
        _setKnightEquipment(knightId, itemIds, false);

        equipmentContract.putItemsIntoStorage(msg.sender, itemIds);
    }

    function removeItems(uint knightId, uint[] memory itemIds) external override onlyOwnerOf(knightId) {
        _setKnightEquipment(knightId, itemIds, true);

        equipmentContract.returnItems(msg.sender, itemIds);
    }

    function addFloorPriceToKnight(uint knightId) external override payable {
        uint feeInToken = serviceFeeInToken * (msg.value / 1e18);

        require(msg.value > 0, "MoonKnight: no value sent");
        require(_knights[knightId].floorPrice < floorPriceCap, "MoonKnight: cannot add more");
        require(acceptedToken.balanceOf(msg.sender) >= feeInToken, "MoonKnight: insufficient token balance");

        _knights[knightId].floorPrice += msg.value;

        bool isSuccess = acceptedToken.transferFrom(msg.sender, owner(), feeInToken);
        require(isSuccess, "MoonKnight: transfer token failed");
    }

    function sacrificeKnight(uint knightId) external override onlyOwnerOf(knightId) {
        Knight storage knight = _knights[knightId];
        uint amount = knight.floorPrice;

        knight.floorPrice = 0;
        _burn(knightId);

        (bool isSuccess,) = msg.sender.call{value: amount}("");
        require(isSuccess, "MoonKnight: refund failed");
    }

    function list(uint knightId, uint price) external override onlyOwnerOf(knightId) {
        require(price >= _knights[knightId].floorPrice, "MoonKnight: under floor price");

        knightsOnSale[knightId] = price;

        emit KnightListed(knightId, price);
    }

    function delist(uint knightId) external override onlyOwnerOf(knightId) {
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

    function takeOffer(uint knightId, address buyerAddr, uint minPrice) external override onlyOwnerOf(knightId) {
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

    function generateKnight(address account) external override onlyOperator {
        uint knightId = _createKnight(0);
        _safeMint(account, knightId);
    }

    function levelUpKnight(uint knightId, uint amount) external override onlyOperator {
        _knights[knightId].level += amount;
    }

    function finalizeDuelResult(uint winningKnightId, uint losingKnightId, uint penaltyInBps) external override onlyOperator {
        Knight storage losingKnight = _knights[losingKnightId];
        uint penaltyAmount = losingKnight.floorPrice * penaltyInBps / BPS;

        _knights[winningKnightId].floorPrice += penaltyAmount;
        losingKnight.floorPrice -= penaltyAmount;
    }

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function _makeTransaction(uint knightId, address buyer, address seller, uint price) private {
        uint floorPrice = price * floorPriceInBps / BPS;
        uint marketFee = price * marketFeeInBps / BPS;

        knightsOnSale[knightId] = 0;
        _knights[knightId].floorPrice += floorPrice;

        (bool transferToSeller,) = seller.call{value: price - (floorPrice + marketFee)}("");
        require(transferToSeller, "MoonKnight: transfer to seller failed");

        (bool isSuccess,) = owner().call{value: marketFee}("");
        require(isSuccess, "MoonKnight: transfer to treasury failed");

        _transfer(seller, buyer, knightId);
    }

    function _createKnight(uint floorPrice) private returns (uint) {
        _knights.push(Knight("", "", 1, floorPrice, 0, 0, 0, 0, 0, 0, 0, 0));
        return _knights.length - 1;
    }

    function _setKnightEquipment(uint knightId, uint[] memory itemIds, bool isRemove) private {
        require(itemIds.length <= 8, "MoonKnight: incorrect ids length");

        Knight storage knight = _knights[knightId];
        bool[] memory itemSet = new bool[](8);

        for (uint i = 0; i < itemIds.length; i++) {
            IEquipment.EquipmentSlot itemSlot = equipmentContract.getItemSlot(itemIds[i]);
            uint itemId = itemIds[i];
            uint setItemId = isRemove ? 0 : itemId;

            require(itemId != 0, "MoonKnight: invalid id");
            require(!itemSet[uint(itemSlot)], "MoonKnight: duplicate items");

            if (itemSlot == IEquipment.EquipmentSlot.MAIN_WEAPON) {
                require(isRemove ? knight.mainWeapon == itemId : knight.mainWeapon == 0, "MoonKnight : invalid mainWeapon");
                knight.mainWeapon = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.MAIN_WEAPON)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.SUB_WEAPON) {
                require(isRemove ? knight.subWeapon == itemId : knight.subWeapon == 0, "MoonKnight : invalid subWeapon");
                knight.subWeapon = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.SUB_WEAPON)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.HEADGEAR) {
                require(isRemove ? knight.headgear == itemId : knight.headgear == 0, "MoonKnight : invalid headgear");
                knight.headgear = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.HEADGEAR)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.ARMOR) {
                require(isRemove ? knight.armor == itemId : knight.armor == 0, "MoonKnight : invalid armor");
                knight.armor = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.ARMOR)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.FOOTWEAR) {
                require(isRemove ? knight.footwear == itemId : knight.footwear == 0, "MoonKnight : invalid footwear");
                knight.footwear = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.FOOTWEAR)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.PANTS) {
                require(isRemove ? knight.pants == itemId : knight.pants == 0, "MoonKnight : invalid pants");
                knight.pants = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.PANTS)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.GLOVES) {
                require(isRemove ? knight.gloves == itemId : knight.gloves == 0, "MoonKnight : invalid gloves");
                knight.gloves = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.GLOVES)] = true;
            } else if (itemSlot == IEquipment.EquipmentSlot.PET) {
                require(isRemove ? knight.pet == itemId : knight.pet == 0, "MoonKnight : invalid pet");
                knight.pet = setItemId;
                itemSet[uint(IEquipment.EquipmentSlot.PET)] = true;
            }
        }
    }

    function _finalizeStartingIndex() private {
        startingIndex = uint(blockhash(block.number)) % _totalSaleKnights;
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
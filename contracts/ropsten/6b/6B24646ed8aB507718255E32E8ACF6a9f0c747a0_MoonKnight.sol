//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IMoonKnight.sol";
import "../interfaces/IEquipment.sol";
import "../interfaces/IPet.sol";
import "../utils/AcceptedToken.sol";

contract MoonKnight is IMoonKnight, ERC721, AcceptedToken, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    uint private constant BPS = 10000;

    IEquipment public equipmentContract;
    IPet public petContract;

    uint public floorPriceInBps = 200;
    uint public marketFeeInBps = 22;
    uint public serviceFeeInToken = 1e20;
    uint public maxLevel = 100;
    string private _uri;

    Version[] public versions;
    mapping(uint => uint) public knightsOnSale;
    mapping(uint => mapping(address => uint)) public knightsWithOffers;
    mapping(string => bool) public reservedNames;

    Knight[] private _knights;
    mapping(uint => uint) private _knightsWithPet;
    mapping(uint => EnumerableSet.UintSet) private _knightSkills;

    constructor(
        IEquipment equipmentAddress,
        IERC20 tokenAddress,
        string memory baseURI,
        uint maxSupply,
        uint salePrice,
        uint startTime,
        uint revealTime,
        string memory provenance
    ) ERC721("MoonKnight", "KNIGHT") AcceptedToken(tokenAddress) {
        equipmentContract = equipmentAddress;
        _uri = baseURI;
        versions.push(Version(0, 0, maxSupply, salePrice, startTime, revealTime, provenance));
    }

    modifier onlyKnightOwner(uint knightId) {
        require(ownerOf(knightId) == msg.sender, "MoonKnight: not knight owner");
        _;
    }

    function setEquipmentContract(IEquipment equipmentAddress) external onlyOwner {
        require(address(equipmentAddress) != address(0));
        equipmentContract = equipmentAddress;
    }

    function setPetContract(IPet petAddress) external onlyOwner {
        require(address(petAddress) != address(0));
        petContract = petAddress;
    }

    function setFloorPriceAndMarketFeeInBps(uint floorPrice, uint marketFee) external onlyOwner {
        require(floorPrice + marketFee <= BPS);
        floorPriceInBps = floorPrice;
        marketFeeInBps = marketFee;
    }

    function setServiceFee(uint value) external onlyOwner {
        serviceFeeInToken = value;
    }

    function setMaxLevel(uint newMaxLevel) external onlyOwner {
        require(newMaxLevel > maxLevel);
        maxLevel = newMaxLevel;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _uri = baseURI;
    }

    function addNewVersion(
        uint maxSupply,
        uint salePrice,
        uint startTime,
        uint revealTime,
        string memory provenance
    ) external onlyOwner {
        uint latestVersionId = getLatestVersion();
        Version memory latestVersion = versions[latestVersionId];

        require(latestVersion.currentSupply == latestVersion.maxSupply);

        versions.push(Version(0, 0, maxSupply, salePrice, startTime, revealTime, provenance));
        emit NewVersionAdded(latestVersionId + 1);
    }

    function claimMoonKnight(uint versionId, uint amount) external override payable {
        Version storage version = versions[versionId];
        uint floorPrice = version.salePrice * 1000 / BPS;

        require(amount > 0 && amount <= 50, "MoonKnight: amount out of range");
        require(block.timestamp >= version.startTime, "MoonKnight: Sale has not started");
        require(version.currentSupply + amount <= version.maxSupply, "MoonKnight: sold out");
        require(msg.value == version.salePrice * amount, "MoonKnight: incorrect value");

        for (uint i = 0; i < amount; i++) {
            uint knightId = _createKnight(floorPrice);
            _safeMint(msg.sender, knightId);
        }

        version.currentSupply += amount;

        (bool isSuccess,) = owner().call{value: msg.value - (floorPrice * amount)}("");
        require(isSuccess);

        if (version.startingIndex == 0 && (version.currentSupply == version.maxSupply || block.timestamp >= version.revealTime)) {
            _finalizeStartingIndex(versionId, version);
        }
    }

    function changeKnightName(
        uint knightId,
        string memory newName
    ) external override onlyKnightOwner(knightId) collectTokenAsFee(serviceFeeInToken, owner()) {
        require(_validateStr(newName), "MoonKnight: invalid name");
        require(reservedNames[newName] == false, "MoonKnight: name already exists");

        Knight storage knight = _knights[knightId];

        // If already named, de-reserve current name
        if (bytes(knight.name).length > 0) {
            reservedNames[knight.name] = false;
        }

        knight.name = newName;
        reservedNames[newName] = true;

        emit NameChanged(knightId, newName);
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
        Knight storage knight = _knights[knightId];
        uint newFloorPrice = knight.floorPrice + msg.value;

        require(msg.value > 0, "MoonKnight: no value sent");
        require(newFloorPrice <= 100 ether, "MoonKnight: cannot add more");
        require(acceptedToken.balanceOf(msg.sender) >= serviceFeeInToken, "MoonKnight: insufficient token balance");

        knight.floorPrice = newFloorPrice;
        acceptedToken.safeTransferFrom(msg.sender, owner(), serviceFeeInToken);

        emit KnightPriceIncreased(knightId, newFloorPrice, serviceFeeInToken);
    }

    function sacrificeKnight(uint knightId) external override nonReentrant onlyKnightOwner(knightId) {
        Knight storage knight = _knights[knightId];
        uint amount = knight.floorPrice;

        knight.floorPrice = 0;
        _burn(knightId);

        (bool isSuccess,) = msg.sender.call{value: amount}("");
        require(isSuccess);
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

    function buy(uint knightId) external override payable nonReentrant {
        uint price = knightsOnSale[knightId];
        address seller = ownerOf(knightId);
        address buyer = msg.sender;

        require(price > 0, "MoonKnight: not on sale");
        require(msg.value == price, "MoonKnight: incorrect value");
        require(buyer != seller, "MoonKnight: cannot buy your own Knight");

        _makeTransaction(knightId, buyer, seller, price);

        emit KnightBought(knightId, buyer, seller, price);
    }

    function offer(uint knightId, uint offerValue) external override nonReentrant payable {
        address buyer = msg.sender;
        uint currentOffer = knightsWithOffers[knightId][buyer];
        bool needRefund = offerValue < currentOffer;
        uint requiredValue = needRefund ? 0 : offerValue - currentOffer;

        require(buyer != ownerOf(knightId), "MoonKnight: owner cannot offer");
        require(offerValue != currentOffer, "MoonKnight: same offer");
        require(msg.value == requiredValue, "MoonKnight: sent value incorrect");

        knightsWithOffers[knightId][buyer] = offerValue;

        if (needRefund) {
            uint returnedValue = currentOffer - offerValue;

            (bool success,) = buyer.call{value: returnedValue}("");
            require(success);
        }

        emit KnightOffered(knightId, buyer, offerValue);
    }

    function takeOffer(
        uint knightId,
        address buyer,
        uint minPrice
    ) external override nonReentrant onlyKnightOwner(knightId) {
        uint offeredValue = knightsWithOffers[knightId][buyer];
        address seller = msg.sender;

        require(offeredValue >= _knights[knightId].floorPrice, "MoonKnight: under floor price");
        require(offeredValue >= minPrice, "MoonKnight: less than min price");
        require(buyer != seller, "MoonKnight: cannot buy your own Knight");

        knightsWithOffers[knightId][buyer] = 0;

        _makeTransaction(knightId, buyer, seller, offeredValue);

        emit KnightBought(knightId, buyer, seller, offeredValue);
    }

    function cancelOffer(uint knightId) external override nonReentrant {
        address sender = msg.sender;
        uint offerValue = knightsWithOffers[knightId][sender];

        require(offerValue > 0, "MoonKnight: no offer found");

        knightsWithOffers[knightId][sender] = 0;

        (bool success,) = sender.call{value: offerValue}("");
        require(success);

        emit KnightOfferCanceled(knightId, sender);
    }

    function learnSkill(uint knightId, uint skillId) external override onlyKnightOwner(knightId) {
        IEquipment.ItemType itemType = equipmentContract.getItemType(skillId);
        EnumerableSet.UintSet storage skills = _knightSkills[knightId];

        require(itemType == IEquipment.ItemType.SKILL_BOOK, "MoonKnight: invalid skill book");

        bool isSuccess = skills.add(skillId);
        if (!isSuccess) revert("MoonKnight: already learned");

        uint[] memory skillIds = new uint[](1);
        skillIds[0] = skillId;
        equipmentContract.putItemsIntoStorage(msg.sender, skillIds);

        emit SkillLearned(knightId, skillId);
    }

    function adoptPet(uint knightId, uint petId) external override onlyKnightOwner(knightId) {
        require(petContract.ownerOf(petId) == msg.sender, "MoonKnight: not pet owner");

        _knightsWithPet[knightId] = petId;
        petContract.bindPet(petId);

        emit PetAdopted(knightId, petId);
    }

    function abandonPet(uint knightId) external override onlyKnightOwner(knightId) {
        uint petId = _knightsWithPet[knightId];

        require(petId != 0, "MoonKnight: no pet");

        _knightsWithPet[knightId] = 0;
        petContract.releasePet(petId);

        emit PetReleased(knightId, petId);
    }

    function levelUp(uint knightId, uint amount) external override onlyOperator {
        Knight storage knight = _knights[knightId];
        uint newLevel = knight.level + amount;

        require(amount > 0);
        require(newLevel <= maxLevel, "MoonKnight: max level reached");

        knight.level = newLevel;

        emit KnightLeveledUp(knightId, newLevel, amount);
    }

    function finalizeDuelResult(
        uint winningKnightId,
        uint losingKnightId,
        uint penaltyInBps
    ) external override onlyOperator {
        require(penaltyInBps <= BPS);

        Knight storage winningKnight = _knights[winningKnightId];
        Knight storage losingKnight = _knights[losingKnightId];
        uint baseFloorPrice = winningKnight.floorPrice > losingKnight.floorPrice ? losingKnight.floorPrice : winningKnight.floorPrice;

        uint penaltyAmount = baseFloorPrice * penaltyInBps / BPS;

        winningKnight.floorPrice += penaltyAmount;
        losingKnight.floorPrice -= penaltyAmount;

        emit DuelConcluded(winningKnightId, losingKnightId, penaltyAmount);
    }

    function getKnight(uint knightId) external view override returns (
        string memory name,
        uint level,
        uint floorPrice,
        uint pet,
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
        level = knight.level;
        floorPrice = knight.floorPrice;
        pet = _knightsWithPet[knightId];
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

    function getKnightLevel(uint knightId) external view override returns (uint) {
        return _knights[knightId].level;
    }

    function getLatestVersion() public view returns (uint) {
        return versions.length - 1;
    }

    function totalSupply() external view returns (uint) {
        return _knights.length;
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
        require(transferToSeller);

        (bool transferToTreasury,) = owner().call{value: marketFee}("");
        require(transferToTreasury);

        _transfer(seller, buyer, knightId);

        emit KnightPriceIncreased(knightId, newPrice, floorPrice);
    }

    function _createKnight(uint floorPrice) private returns (uint knightId) {
        _knights.push(Knight("", 1, floorPrice, 0, 0, 0, 0, 0, 0, 0, 0, 0));
        knightId = _knights.length - 1;
        emit KnightCreated(knightId, floorPrice);
    }

    function _setKnightEquipment(uint knightId, uint[] memory itemIds, bool isRemove) private {
        require(knightsOnSale[knightId] == 0, "MoonKnight: cannot change items while on sale");
        require(itemIds.length > 0, "MoonKnight: no item");

        Knight storage knight = _knights[knightId];
        bool[] memory itemSet = new bool[](9);

        for (uint i = 0; i < itemIds.length; i++) {
            uint itemId = itemIds[i];
            uint updatedItemId = isRemove ? 0 : itemId;
            IEquipment.ItemType itemType = equipmentContract.getItemType(itemId);

            require(itemId != 0, "MoonKnight: invalid itemId");
            require(itemType != IEquipment.ItemType.SKILL_BOOK, "MoonKnight: cannot equip skill book");
            require(!itemSet[uint(itemType)], "MoonKnight: duplicate itemType");

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

    function _finalizeStartingIndex(uint versionId, Version storage version) private {
        uint startingIndex = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % version.maxSupply;
        if (startingIndex == 0) startingIndex = startingIndex + 1;
        version.startingIndex = startingIndex;

        emit StartingIndexFinalized(versionId, startingIndex);
    }

    /**
     * @dev Check if the name string is valid (Alphanumeric and spaces without leading or trailing space)
     */
    function _validateStr(string memory str) internal pure returns (bool) {
        bytes memory b = bytes(str);
        if (b.length < 1) return false;
        if (b.length > 20) return false;

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
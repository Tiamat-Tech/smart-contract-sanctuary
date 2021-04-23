//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libs/ERC1155.sol";
import "./IEquipment.sol";
import "./IEquipmentVendor.sol";
import "../utils/AcceptedToken.sol";

contract Equipment is IEquipment, ERC1155, AcceptedToken {
    using Address for address;

    // Contract for interacting with vendor machine.
    IEquipmentVendor public vendorContract;

    // Mapping from current item to its next tier item.
    mapping(uint => uint) public nextTierItems;

    uint public upgradeFeeInToken;
    uint public mintFeeInToken;

    // Mapping from item to its information.
    Item[] private _items;

    constructor(
        string memory _uri,
        IERC20 tokenAddress,
        uint _upgradeFeeInToken,
        uint _mintFeeInToken
    ) ERC1155(_uri) AcceptedToken(tokenAddress) {
        upgradeFeeInToken = _upgradeFeeInToken;
        mintFeeInToken = _mintFeeInToken;
    }

    function setEquipmentVendor(IEquipmentVendor contractAddr) external onlyOwner {
        require(address(contractAddr) != address(0), "Equipment: zero address");
        vendorContract = contractAddr;
    }

    function setURI(string memory uri) external onlyOwner {
        _setURI(uri);
    }

    function setUpgradeFeeInToken(uint fee) external onlyOwner {
        upgradeFeeInToken = fee;
    }

    function setMintFeeInToken(uint fee) external onlyOwner {
        mintFeeInToken = fee;
    }

    function createItem(
        string memory name,
        uint16 maxSupply,
        ItemType itemType,
        Rarity rarity
    ) external override onlyOwner {
        require(maxSupply > 0, "Equipment: invalid maxSupply");

        _items.push(Item(name, maxSupply, 0, 0, 1, 0, itemType, rarity));

        emit ItemCreated(_items.length - 1, name, maxSupply, itemType, rarity);
    }

    function addNextTierItem(uint itemId, uint8 upgradeAmount) external override onlyOwner {
        Item storage currentItem = _items[itemId];

        require(upgradeAmount > 1, "Equipment: invalid upgradeAmount");
        require(currentItem.maxSupply >= upgradeAmount, "Equipment: maxSupply less than upgradeAmount");

        currentItem.upgradeAmount = upgradeAmount;

        _items.push(Item(
            currentItem.name,
            currentItem.maxSupply / uint16(upgradeAmount),
            0,
            0,
            currentItem.tier + 1,
            0,
            currentItem.itemType,
            currentItem.rarity
        ));

        uint nextTierItemId = _items.length - 1;
        nextTierItems[itemId] = nextTierItemId;

        emit ItemUpgradable(itemId, nextTierItemId, upgradeAmount);
    }

    function upgradeItem(uint itemId) external override {
        Item storage currentItem = _items[itemId];
        uint8 upgradeAmount = currentItem.upgradeAmount;
        uint nextTierItemId = nextTierItems[itemId];
        address sender = msg.sender;

        require(nextTierItemId != 0, "Equipment: not upgradable");
        require(_balances[itemId][sender] >= upgradeAmount, "Equipment: insufficient item amount");
        require(acceptedToken.balanceOf(sender) >= upgradeFeeInToken, "Equipment: insufficient token balance");

        _balances[itemId][sender] -= upgradeAmount;
        currentItem.burnt += upgradeAmount;
        emit TransferSingle(sender, sender, address(0), itemId, upgradeAmount);

        _balances[nextTierItemId][sender] += 1;
        _items[nextTierItemId].minted += 1;
        emit TransferSingle(sender, address(0), sender, nextTierItemId, 1);

        bool isSuccess = acceptedToken.transferFrom(sender, owner(), upgradeFeeInToken);
        require(isSuccess, "Equipment: transfer token failed");
    }

    function rollEquipmentGacha(uint vendorId, uint amount) external override {
        address sender = msg.sender;

        require(!sender.isContract(), "Equipment: contract not allowed");
        require(amount > 0 && amount <= 10, "Equipment: amount out of range");
        require(acceptedToken.balanceOf(sender) >= upgradeFeeInToken * amount, "Equipment: insufficient token balance");

        uint totalReceivedItems = vendorContract.mintRandomItems(sender, vendorId, amount);

        bool isSuccess = acceptedToken.transferFrom(sender, owner(), upgradeFeeInToken * totalReceivedItems);
        require(isSuccess, "Equipment: transfer token failed");
    }

    function mint(address account, uint itemId, uint16 amount) external override onlyOperator returns (bool) {
        Item storage item = _items[itemId];

        require(item.minted + amount <= item.maxSupply, "Equipment: max cap is reached");

        _balances[itemId][account] += amount;
        item.minted += amount;

        emit TransferSingle(msg.sender, address(0), account, itemId, amount);

        return item.minted == item.maxSupply;
    }

    function putItemsIntoStorage(address account, uint[] memory itemIds) external override onlyOperator {
        for (uint i = 0; i < itemIds.length; i++) {
            require(_balances[itemIds[i]][account] >= 1, "Equipment: exceeds balance");
            _balances[itemIds[i]][account] -= 1;
        }
    }

    function returnItems(address account, uint[] memory itemIds) external override onlyOperator {
        for (uint i = 0; i < itemIds.length; i++) {
            _balances[itemIds[i]][account] += 1;
        }
    }

    function getItem(uint itemId) external view override returns (Item memory item) {
        return _items[itemId];
    }

    function getItemType(uint itemId) external view override returns (ItemType) {
        return _items[itemId].itemType;
    }

    function isOutOfStock(uint itemId, uint16 amount) external view override returns (bool) {
        Item memory item = _items[itemId];
        return item.minted + amount > item.maxSupply;
    }
}
//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IEquipment.sol";
import "./ERC1155.sol";
import "../utils/PermissionGroup.sol";

contract Equipment is IEquipment, PermissionGroup, ERC1155 {
    // Mapping from current item to its next tier item.
    mapping(uint => uint) public nextTierItems;

    // Fee to upgrade item.
    uint public upgradeFeeInWei;

    // Fee for playing gacha to collect random items.
    uint public mintFeeInWei;

    // Mapping from item to its information.
    Item[] private _items;

    constructor(string memory _uri, uint _upgradeFeeInWei, uint _mintFeeInWei) ERC1155(_uri) {
        upgradeFeeInWei = _upgradeFeeInWei;
        mintFeeInWei = _mintFeeInWei;
    }

    function setURI(string memory uri) external onlyOwner {
        _setURI(uri);
    }

    function setMintFee(uint fee) external onlyOwner {
        mintFeeInWei = fee;
    }

    function setUpgradeFee(uint fee) external onlyOwner {
        upgradeFeeInWei = fee;
    }

    function withdrawEther() external onlyOwner {
        (bool transferResult,) = payable(owner()).call{value: address(this).balance}("");
        require(transferResult, "Equipment: transfer failed");
    }

    /**
     * @dev See {IEquipment-createItem}.
     */
    function createItem(
        string memory name,
        uint32 maxSupply,
        EquipmentSlot slot,
        Rarity rarity
    ) external override onlyOwner {
        require(maxSupply > 0, "Equipment: invalid maxSupply");

        _items.push(Item(name, maxSupply, 0, 0, 1, 0, slot, rarity));

        emit ItemCreated(_items.length - 1);
    }

    /**
     * @dev See {IEquipment-addNextTierItem}.
     */
    function addNextTierItem(uint itemId, uint8 upgradeAmount) external override onlyOwner {
        Item storage currentItem = _items[itemId];

        require(upgradeAmount > 1, "Equipment: invalid upgradeAmount");
        require(currentItem.maxSupply >= upgradeAmount, "Equipment: maxSupply less than upgradeAmount");

        currentItem.upgradeAmount = upgradeAmount;

        _items.push(Item(
            currentItem.name,
            currentItem.maxSupply / uint32(upgradeAmount),
            0,
            0,
            currentItem.tier + 1,
            0,
            currentItem.slot,
            currentItem.rarity
        ));

        uint nextTierItemId = _items.length - 1;
        nextTierItems[itemId] = nextTierItemId;

        emit ItemUpgradable(itemId, nextTierItemId, upgradeAmount);
    }

    /**
     * @dev See {IEquipment-mint}.
     */
    function mint(address account, uint itemId, uint32 amount) external override payable onlyOperator returns (bool) {
        require(msg.value == mintFeeInWei, "EquipmentVendor: incorrect value");

        Item storage item = _items[itemId];

        require(item.minted + amount <= item.maxSupply, "Equipment: max cap is reached");

        _balances[itemId][account] += amount;
        item.minted += amount;

        emit TransferSingle(msg.sender, address(0), account, itemId, amount);

        return item.minted == item.maxSupply;
    }

    /**
     * @dev See {IEquipment-mintItems}.
     */
    function returnItems(address account, uint256[] memory itemIds) external override onlyOperator {
        for (uint i = 0; i < itemIds.length; i++) {
            _balances[itemIds[i]][account] += 1;
        }
    }

    /**
     * @dev See {IEquipment-burnItems}.
     */
    function takeItemsAway(address account, uint256[] memory itemIds) external override onlyOperator {
        for (uint i = 0; i < itemIds.length; i++) {
            require(_balances[itemIds[i]][account] >= 1, "Equipment: exceeds balance");
            _balances[itemIds[i]][account] -= 1;
        }
    }

    /**
     * @dev See {IEquipment-upgradeItem}.
     */
    function upgradeItem(uint itemId) external override payable {
        require(msg.value == upgradeFeeInWei, "Equipment: upgrade fee incorrect");

        uint nextTierItemId = nextTierItems[itemId];

        require(nextTierItemId != 0, "Equipment: not upgradable");

        address sender = msg.sender;
        Item storage currentItem = _items[itemId];
        uint8 upgradeAmount = currentItem.upgradeAmount;

        require(_balances[itemId][sender] >= upgradeAmount, "Equipment: insufficient balance");

        _balances[itemId][sender] -= upgradeAmount;
        currentItem.burnt += upgradeAmount;
        emit TransferSingle(sender, sender, address(0), itemId, upgradeAmount);

        _balances[nextTierItemId][sender] += 1;
        _items[nextTierItemId].minted += 1;
        emit TransferSingle(sender, address(0), sender, nextTierItemId, 1);
    }

    /**
     * @dev See {IEquipment-getItem}.
     */
    function getItem(uint itemId) external view override returns (Item memory item) {
        return _items[itemId];
    }

    /**
     * @dev See {IEquipment-getItemSlot}.
     */
    function getItemSlot(uint itemId) external view override returns (EquipmentSlot) {
        return _items[itemId].slot;
    }
}
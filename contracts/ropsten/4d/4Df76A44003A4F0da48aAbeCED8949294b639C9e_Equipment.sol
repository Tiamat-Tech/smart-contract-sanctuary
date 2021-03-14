//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IEquipment.sol";
import "./ERC1155.sol";
import "../utils/PermissionGroup.sol";

contract Equipment is IEquipment, PermissionGroup, ERC1155 {
    // Mapping from current item to its next tier item.
    mapping(uint => uint) public nextTierItems;

    // Fee to upgrade item.
    uint public upgradeFee;

    // Mapping from item to its information.
    Item[] private _items;

    constructor(uint upgradeFee_, string memory baseURI_) ERC1155(baseURI_) {
        upgradeFee = upgradeFee_;
    }

    /**
     * @notice Sets fee for item upgrade.
     */
    function setUpgradeFee(uint fee) external onlyOperator {
        upgradeFee = fee;
    }

    /**
     * @notice Withdraws ether from this contract.
     */
    function withdrawEther() external onlyOperator {
        (bool transferResult,) = payable(owner()).call{value: address(this).balance}("");
        require(transferResult, "Equipment: transfer to development fund failed");
    }

    /**
     * @dev See {IEquipment-getItem}.
     */
    function getItem(uint itemId) external view override returns (
        string memory name,
        uint8 tier,
        uint8 numberToUpgrade,
        uint circulatingSupply,
        uint maxSupply,
        EquipmentSlot slot,
        Rarity rarity
    ) {
        Item memory item = _items[itemId];

        name = item.name;
        tier = item.tier;
        numberToUpgrade = item.numberToUpgrade;
        circulatingSupply = item.circulatingSupply;
        maxSupply = item.maxSupply;
        slot = item.slot;
        rarity = item.rarity;
    }

    /**
     * @dev See {IEquipment-createItem}.
     */
    function createItem(string memory name, uint maxSupply, EquipmentSlot slot, Rarity rarity) external override onlyOperator {
        uint nextId = _items.length + 1;
        _items[nextId] = Item(name, 1, 0, 0, maxSupply, slot, rarity);
    }

    /**
     * @dev See {IEquipment-addNextTierItem}.
     */
    function addNextTierItem(uint itemId, uint8 numberToUpgrade) external override onlyOperator {
        uint nextItemId = _items.length + 1;
        Item storage currentItem = _items[itemId];

        currentItem.numberToUpgrade = numberToUpgrade;

        _items[nextItemId] = Item(
            currentItem.name,
            currentItem.tier + 1,
            0,
            0,
            currentItem.maxSupply / numberToUpgrade,
            currentItem.slot,
            currentItem.rarity
        );

        nextTierItems[itemId] = nextItemId;
    }

    /**
     * @dev See {IEquipment-mintItems}.
     */
    function mintItems(address account, uint256[] memory itemIds) external override onlyOperator {
        address operator = _msgSender();
        uint[] memory amounts;

        for (uint i = 0; i < itemIds.length; i++) {
            _balances[itemIds[i]][account] += 1;
            amounts[i] = 1;
        }

        emit TransferBatch(operator, address(0), account, itemIds, amounts);
    }

    /**
     * @dev See {IEquipment-burnItems}.
     */
    function burnItems(address account, uint256[] memory itemIds) external override onlyOperator {
        address operator = _msgSender();
        uint[] memory amounts;

        for (uint i = 0; i < itemIds.length; i++) {
            require(_balances[itemIds[i]][account] >= 1, "Equipment: burn amount exceeds balance");
            _balances[itemIds[i]][account] -= 1;
            amounts[i] = 1;
        }

        emit TransferBatch(operator, account, address(0), itemIds, amounts);
    }

    /**
     * @dev See {IEquipment-upgradeItem}.
     */
    function upgradeItem(uint itemId) external override payable {
        uint nextTierItemId = nextTierItems[itemId];
        Item storage currentItem = _items[itemId];
        uint8 numberToUpgrade = currentItem.numberToUpgrade;

        require(nextTierItemId != 0, "Equipment: item is not upgradable");
        require(msg.value == upgradeFee, "Equipment: upgrade fee is not correct");
        require(_balances[itemId][_msgSender()] >= numberToUpgrade, "Equipment: insufficient balance for upgrade");

        _balances[itemId][_msgSender()] -= numberToUpgrade;
        currentItem.circulatingSupply -= numberToUpgrade;

        _balances[nextTierItemId][_msgSender()] += 1;
        _items[nextTierItemId].circulatingSupply += 1;
    }
}
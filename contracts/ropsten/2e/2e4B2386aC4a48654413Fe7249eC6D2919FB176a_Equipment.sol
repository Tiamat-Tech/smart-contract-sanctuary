//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libs/ERC1155.sol";
import "./IEquipment.sol";
import "./IEquipmentVendor.sol";
import "../utils/PermissionGroup.sol";
import "../utils/TokenWithdrawable.sol";

contract Equipment is IEquipment, ERC1155, PermissionGroup, TokenWithdrawable {
    using Address for address;

    // Contract for interacting with vendor machine.
    IEquipmentVendor public vendorContract;

    // Token to be used in the ecosystem.
    IERC20 public acceptedToken;

    // Mapping from current item to its next tier item.
    mapping(uint => uint) public nextTierItems;

    uint public upgradeFeeInWei;
    uint public mintFeeInWei;
    uint public upgradeFeeInToken;
    uint public mintFeeInToken;

    // Mapping from item to its information.
    Item[] private _items;

    constructor(
        string memory _uri,
        uint _upgradeFeeInWei,
        uint _mintFeeInWei,
        uint _upgradeFeeInToken,
        uint _mintFeeInToken
    ) ERC1155(_uri) {
        upgradeFeeInWei = _upgradeFeeInWei;
        mintFeeInWei = _mintFeeInWei;
        upgradeFeeInToken = _upgradeFeeInToken;
        mintFeeInToken = _mintFeeInToken;
    }

    function setEquipmentVendor(IEquipmentVendor contractAddr) external onlyOwner {
        require(address(contractAddr) != address(0), "Equipment: zero address");
        vendorContract = contractAddr;
    }

    function setAcceptedTokenContract(IERC20 tokenAddress) external onlyOwner {
        acceptedToken = tokenAddress;
    }

    function setURI(string memory uri) external onlyOwner {
        _setURI(uri);
    }

    function setUpgradeFeeInWei(uint fee) external onlyOwner {
        upgradeFeeInWei = fee;
    }

    function setMintFeeInWei(uint fee) external onlyOwner {
        mintFeeInWei = fee;
    }

    function setUpgradeFeeInToken(uint fee) external onlyOwner {
        upgradeFeeInToken = fee;
    }

    function setMintFeeInToken(uint fee) external onlyOwner {
        mintFeeInToken = fee;
    }

    function withdrawEther() external onlyOwner {
        (bool isSuccess,) = owner().call{value: address(this).balance}("");
        require(isSuccess, "Equipment: transfer failed");
    }

    function createItem(
        string memory name,
        uint16 maxSupply,
        EquipmentSlot slot,
        Rarity rarity
    ) external override onlyOwner {
        require(maxSupply > 0, "Equipment: invalid maxSupply");

        _items.push(Item(name, maxSupply, 0, 0, 1, 0, slot, rarity));

        emit ItemCreated(_items.length - 1, name, maxSupply, slot, rarity);
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
            currentItem.slot,
            currentItem.rarity
        ));

        uint nextTierItemId = _items.length - 1;
        nextTierItems[itemId] = nextTierItemId;

        emit ItemUpgradable(itemId, nextTierItemId, upgradeAmount);
    }

    function rollEquipmentGacha(uint vendorId, uint amount) external override payable {
        address sender = msg.sender;
        bool isUsingToken = address(acceptedToken) != address(0);

        require(!sender.isContract(), "Equipment: contract not allowed");
        require(amount > 0 && amount <= 10, "Equipment: amount out of range");
        if (isUsingToken) {
            require(acceptedToken.balanceOf(sender) >= upgradeFeeInToken, "Equipment: insufficient token balance");
        } else {
            require(msg.value == mintFeeInWei * amount, "Equipment: incorrect value");
        }

        uint totalReceivedItems = vendorContract.mintRandomItems(sender, vendorId, amount);
        uint totalLossItems = amount - totalReceivedItems;

        if (isUsingToken) {
            bool isSuccess = acceptedToken.transferFrom(sender, owner(), upgradeFeeInToken * totalReceivedItems);
            require(isSuccess, "Equipment: transfer token failed");
        } else if (totalLossItems != 0) {
            (bool refundResult,) = sender.call{value: mintFeeInWei * totalLossItems}("");
            require(refundResult, "Equipment: refund failed");
        }
    }

    function mint(address account, uint itemId, uint16 amount) external override onlyOperator returns (bool) {
        Item storage item = _items[itemId];

        require(item.minted + amount <= item.maxSupply, "Equipment: max cap is reached");

        _balances[itemId][account] += amount;
        item.minted += amount;

        emit TransferSingle(msg.sender, address(0), account, itemId, amount);

        return item.minted == item.maxSupply;
    }

    function returnItems(address account, uint256[] memory itemIds) external override onlyOperator {
        for (uint i = 0; i < itemIds.length; i++) {
            _balances[itemIds[i]][account] += 1;
        }
    }

    function putItemsIntoStorage(address account, uint256[] memory itemIds) external override onlyOperator {
        for (uint i = 0; i < itemIds.length; i++) {
            require(_balances[itemIds[i]][account] >= 1, "Equipment: exceeds balance");
            _balances[itemIds[i]][account] -= 1;
        }
    }

    function upgradeItem(uint itemId) external override payable {
        bool isUsingToken = address(acceptedToken) != address(0);
        uint nextTierItemId = nextTierItems[itemId];
        address sender = msg.sender;
        Item storage currentItem = _items[itemId];
        uint8 upgradeAmount = currentItem.upgradeAmount;

        if (isUsingToken) {
            require(acceptedToken.balanceOf(msg.sender) >= upgradeFeeInToken, "Equipment: insufficient token balance");
        } else {
            require(msg.value == upgradeFeeInWei, "Equipment: incorrect value");
        }
        require(nextTierItemId != 0, "Equipment: not upgradable");
        require(_balances[itemId][sender] >= upgradeAmount, "Equipment: insufficient balance");

        _balances[itemId][sender] -= upgradeAmount;
        currentItem.burnt += upgradeAmount;
        emit TransferSingle(sender, sender, address(0), itemId, upgradeAmount);

        _balances[nextTierItemId][sender] += 1;
        _items[nextTierItemId].minted += 1;
        emit TransferSingle(sender, address(0), sender, nextTierItemId, 1);

        if (isUsingToken) {
            bool isSuccess = acceptedToken.transferFrom(sender, owner(), upgradeFeeInToken);
            require(isSuccess, "Equipment: transfer token failed");
        }
    }

    function getItem(uint itemId) external view override returns (Item memory item) {
        return _items[itemId];
    }

    function getItemSlot(uint itemId) external view override returns (EquipmentSlot) {
        return _items[itemId].slot;
    }

    function isOutOfStock(uint itemId, uint16 amount) external view override returns (bool) {
        Item memory item = _items[itemId];
        return item.minted + amount > item.maxSupply;
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IArena.sol";
import "./interfaces/IAvania.sol";
import "./interfaces/IItem.sol";
import "./libraries/Number.sol";

import "hardhat/console.sol";

/**
 * @dev Implementation of Arena.
 */
contract Arena is Ownable, IArena {
    using EnumerableSet for EnumerableSet.AddressSet;

    IAvania public avania;
    EnumerableSet.AddressSet private _items;

    uint256 public price;

    /**
     * @dev Initializes the contract
     */
    constructor(address avania_) {
        avania = IAvania(avania_);
        price = 1e17;
    }

    /**
     * @dev Fallback function that delegates calls to buy items. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _buy();
    }

    /**
     * @dev Fallback function that delegates calls to buy items. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _buy();
    }

    /**
     * @dev Gets items.
     */
    function items(address account) public view virtual returns (uint256[] memory) {
        uint256[] memory items = new uint256[](_items.length());
        for (uint256 i = 0; i < _items.length(); ++i) {
            items[i] = IItem(_items.at(i)).balanceOf(account);
        }
        return items;
    }

    /**
     * @dev See {IArena-setItems}.
     */
    function setItems(address[] memory items_) public virtual override onlyOwner returns (address[] memory) {
        for (uint256 i = 0; i < items_.length; ++i) {
            _items.add(items_[i]);
        }
        return items_;
    }

    /**
     * @dev Sets item price.
     */
    function setPrice(uint256 price_) public virtual onlyOwner returns (uint256) {
        require(price_ > 0, "Arena: cannot be zero");
        price = price_;
        return price_;
    }

    /**
     * @dev Withdraws all.
     */
    function withdraw(address payable account) public virtual onlyOwner returns (uint256) {
        require(account != address(0), "Arena: cannot be zero address");
        Address.sendValue(account, address(this).balance);
    }

    /**
     * @dev See {IArena-unbox}.
     *
     * 1. gold - min: 50, max: 1000
     * 2. diamond - min: 50, max: 1000
     * 3. xp - min: 120, max: 3000
     * 4. key
     * 5. shard1 - 1
     * 6. shard2 - 1
     * 7. shard3 - 1
     * 8. shard4 - 1
     * 9. shard5 - 1
     */
    function unbox() public virtual override returns (bool) {
        require(_getKey(_msgSender()) > 0, "Arena: insufficient key");
        require(avania.fullHero(_msgSender()), "Arena: missing hero");

        uint256[9] memory mins = [uint256(50), 50, 120, 0, 1, 1, 1, 1, 1];
        uint256[9] memory maxs = [uint256(1000), 1000, 3000, 0, 1, 1, 1, 1, 1];

        uint256 randNumber = _randomNumber();
        for (uint256 i = 0; i < _items.length(); ++i) {
            if (i != 3) {
                // mint items
                uint256 rand = Number.slice(randNumber, 20, i * 20);
                IItem(_items.at(i)).mint(_msgSender(), Math.max(rand % maxs[i], mins[i]));
            } else {
                // burn key
                IItem(_items.at(i)).burn(_msgSender(), 1);
            }
        }

        emit Unbox(_msgSender());

        return true;
    }

    /**
     * @dev Generates random number.
     */
    function _randomNumber() internal virtual returns (uint256) {
        return uint256(blockhash(block.number - 1));
    }

    /**
     * @dev Gets key amount.
     */
    function _getKey(address account) internal virtual returns (uint256) {
        return IItem(_items.at(3)).balanceOf(account);
    }

    /**
     * @dev Buys items
     */
    function _buy() internal virtual returns (bool) {
        uint256 quantity = msg.value / price;
        uint256 cost = quantity * price;

        // mint key
        IItem(_items.at(3)).mint(_msgSender(), quantity);

        // return remainings (exclude dust)
        if (msg.value - cost > 1e3) {
            Address.sendValue(payable(_msgSender()), msg.value - cost);
        }

        return true;
    }
}
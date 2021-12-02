// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IArena.sol";
import "./interfaces/IAvania.sol";
import "./interfaces/IItem.sol";
import "./libraries/Number.sol";

/**
 * @dev Implementation of Arena.
 */
contract Arena is Ownable, IArena {
    IAvania public avania;
    address[] public items;

    /**
     * @dev Initializes the contract
     */
    constructor(address avania_) {
        avania = IAvania(avania_);
    }

    /**
     * @dev See {IArena-setItems}.
     */
    function setItems(address[] memory items_) public virtual override returns (bool) {
        items = items_;
    }

    /**
     * @dev See {IArena-combat}.
     */
    function combat(uint256[] memory tokenIds) public virtual override returns (bool) {
        require(tokenIds.length == 5, "Arena: missing hero");
        require(_checkOwner(tokenIds), "Arena: not owner");

        for (uint256 i = 0; i < items.length; ++i) {
            uint256 rand = Number.slice(_randomNumber(), 20, i * 20);
            uint256 balance = IItem(items[i]).balanceOf(_msgSender());
            if (rand % 2 == 0 && balance > 0) {
                IItem(items[i]).burn(_msgSender(), Math.min(rand, balance));
            }
        }
    }

    /**
     * @dev Checks if has ownership
     */
    function _checkOwner(uint256[] memory tokenIds) internal virtual returns (bool) {
        bool isOwner = true;
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            if (avania.ownerOf(tokenIds[i]) != _msgSender()) {
                isOwner = false;
            }
        }
        return isOwner;
    }

    /**
     * @dev Generates random number.
     */
    function _randomNumber() internal virtual returns (uint256) {
        return uint256(blockhash(block.number - 1));
    }
}
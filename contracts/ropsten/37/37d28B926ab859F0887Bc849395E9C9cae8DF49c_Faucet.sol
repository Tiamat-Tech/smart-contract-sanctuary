// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IItem.sol";

/**
 * @dev Implementation of Faucet.
 */
contract Faucet is Ownable {
    address[] public items;

    /**
     * @dev Initializes the contract
     */
    constructor() {
        //
    }

    /**
     * @dev Gets items balance.
     */
    function balances() public view virtual returns (uint256[9] memory) {
        uint256[9] memory balances;
        for (uint256 i = 0; i < items.length; ++i) {
            balances[i] = IItem(items[i]).balanceOf(_msgSender());
        }
        return balances;
    }

    /**
     * @dev Sets items
     */
    function setItems(address[] memory items_) public virtual onlyOwner returns (bool) {
        items = items_;
        return true;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to user
     */
    function mint(uint256 amount) public virtual returns (bool) {
        for (uint256 i = 0; i < items.length; ++i) {
            IItem(items[i]).mint(_msgSender(), amount);
        }
        return true;
    }
}
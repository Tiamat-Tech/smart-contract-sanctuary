// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

import "./interfaces/IItem.sol";

/**
 * @dev Implementation of Faucet.
 */
contract Faucet is Context {
    address[] public assets;

    /**
     * @dev Initializes the contract
     */
    constructor(address[] memory assets_) {
        assets = assets_;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to user
     */
    function mint(uint256 amount) public virtual returns (bool) {
        for (uint256 i = 0; i < assets.length; ++i) {
            IItem(assets[i]).mint(_msgSender(), amount);
        }
        return true;
    }
}
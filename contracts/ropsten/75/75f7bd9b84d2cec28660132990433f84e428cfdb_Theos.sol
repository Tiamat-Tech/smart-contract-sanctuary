// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Theos is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    function initialize(string memory tokenName, string memory symbol) public initializer {
        __ERC20_init(tokenName, symbol);
        __Ownable_init();
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }
}
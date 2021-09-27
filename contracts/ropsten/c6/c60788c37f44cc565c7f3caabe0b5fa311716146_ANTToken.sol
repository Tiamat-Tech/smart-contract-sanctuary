// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

// import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/ERC777Upgradeable.sol";
import "hardhat/console.sol";

/**
 * @title ANTToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 */

contract ANTToken is ERC777Upgradeable {
    address payable owner;

    function initialize() public initializer {
        address[] memory adds = new address[](0);
        __ERC777_init("ANT777", "ANT", adds);
        owner = payable(msg.sender);
        _mint(msg.sender, 1000* 10**6 * (10 ** uint256(decimals())), "", "");
    }
}
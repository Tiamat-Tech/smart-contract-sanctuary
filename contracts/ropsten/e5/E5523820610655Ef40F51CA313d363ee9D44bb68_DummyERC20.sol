//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";

contract DummyERC20 is ERC20, ERC165 {
    constructor(string memory name_, string memory symbol_, uint256 supply_) ERC20(name_, symbol_) {
        _registerInterface(type(IERC20).interfaceId);
        _mint(msg.sender,supply_);
    }
}
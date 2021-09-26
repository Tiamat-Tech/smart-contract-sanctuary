// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SharkShake is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply
    ) ERC20 (name, symbol) {
        _mint(msg.sender, totalSupply * (10 ** decimals()));
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
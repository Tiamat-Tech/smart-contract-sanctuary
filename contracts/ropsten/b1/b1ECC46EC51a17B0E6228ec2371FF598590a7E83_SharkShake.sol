// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SharkShake is ERC20 {
    constructor() ERC20 ("Game Dao Token", "gdt") {
        uint256 totalSupply  = 100000000 * (10 ** 18);
        _mint(msg.sender, totalSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
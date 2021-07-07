// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "contracts/token/ERC20/ERC20.sol";
import "contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "contracts/access/Ownable.sol";

contract OwnnoMint is ERC20, ERC20Burnable {
    constructor() ERC20("Ownno Mint", "OWNA") {
        _mint(msg.sender, 8999000100 * 10 ** decimals());
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract JAC is Ownable, ERC20Burnable {

    constructor(address wallet) Ownable() ERC20("Japan All Culture+","JAC+") {
        _mint(wallet, (2 * (10 ** 8)) * (10 ** 18));
    }
}
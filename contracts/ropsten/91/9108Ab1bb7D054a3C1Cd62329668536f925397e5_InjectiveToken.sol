// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InjectiveToken is ERC20 {
    address private constant initialSupplyOwner = 0x15ae150d7dC03d3B635EE90b85219dBFe071ED35;
    
    constructor() ERC20("Injective Protocol", "INJ") {
        _mint(initialSupplyOwner, 100_000_000e18);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GTToken is ERC20 {
    constructor(address source) ERC20("GT Token", "GTT") public {
        _setupDecimals(2);
        _mint(source, 2000000000);
    }
}
// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "./MintableERC20.sol";

contract MockLDO is MintableERC20 {
    constructor() public MintableERC20("Lido DAO Token", "LDO") {}
}
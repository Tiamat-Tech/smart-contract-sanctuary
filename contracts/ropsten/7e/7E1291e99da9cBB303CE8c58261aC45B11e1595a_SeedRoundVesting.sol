// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./Erc20MultiVesting.sol";

contract SeedRoundVesting is Erc20MultiVesting {
    constructor() Erc20MultiVesting(0xFFBfdBac865F1a0911Ab2E0F00b7807F98c38362, 4000000000) {
        _allocate(0x6FCCBfC8Dc7EFe5088510588149d774E92A95fd4, 1000000000, 1625601128, 300000000, 300, 300, 150000000);
    }
}
// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract ShibaInu is ERC20PresetMinterPauser{
    constructor () ERC20PresetMinterPauser("Floki Shiba Inu","Floki")
    {

    }
}
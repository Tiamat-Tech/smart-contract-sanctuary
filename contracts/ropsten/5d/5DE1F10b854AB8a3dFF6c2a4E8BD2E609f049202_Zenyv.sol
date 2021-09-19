// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract Zenyv is ERC20PresetMinterPauser {
    address public admin;

    constructor() ERC20PresetMinterPauser('Zenyv.com', 'Zenyv'){
    }
}
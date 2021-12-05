// SPDX-License-Identifier: MIT
// @author: https://github.com/SHA-2048

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";

contract TheYearOfTheZeroX is ERC1155PresetMinterPauser {

    constructor(string memory uri) ERC1155PresetMinterPauser(uri)
    {
        _mint(_msgSender(), 2021, 1011, 'The Year Of The 0x');
    }
}
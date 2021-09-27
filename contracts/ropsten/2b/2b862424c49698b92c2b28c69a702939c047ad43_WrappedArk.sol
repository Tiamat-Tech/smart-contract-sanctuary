// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract WrappedArk is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("Wrapped ARK Token", "wARK"){}
}
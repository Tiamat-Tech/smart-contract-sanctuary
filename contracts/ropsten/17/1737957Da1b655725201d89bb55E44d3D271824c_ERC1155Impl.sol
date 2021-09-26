// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/presets/ERC1155PresetMinterPauser.sol";

contract ERC1155Impl is ERC1155PresetMinterPauser {
    constructor(string memory uri) public ERC1155PresetMinterPauser(uri) {}

    // TODO Review mint/burn
}
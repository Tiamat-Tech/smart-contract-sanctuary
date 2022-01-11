// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";

contract Traceables is ERC1155PresetMinterPauser {
    uint256 public constant xx = 1;
    uint256 public constant yy = 2;
    uint256 public constant zz = 3;

    constructor(string memory uri) ERC1155PresetMinterPauser(uri) {
        _mint(msg.sender, xx, 10**10, "");
        _mint(msg.sender, yy, 10**10, "");
        _mint(msg.sender, zz, 10**10, "");
    }
}
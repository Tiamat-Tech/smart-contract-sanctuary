//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";

contract MockNFT is ERC1155PresetMinterPauser {
    constructor() ERC1155PresetMinterPauser("https://testapi.com/") {}
}
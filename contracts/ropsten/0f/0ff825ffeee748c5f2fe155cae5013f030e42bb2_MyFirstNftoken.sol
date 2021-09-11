// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract MyFirstNftoken is ERC721PresetMinterPauserAutoId {
    constructor() ERC721PresetMinterPauserAutoId("MyFirstNftoken", "MFNFT", "https://aisthisi.art/metadata/") {}

}
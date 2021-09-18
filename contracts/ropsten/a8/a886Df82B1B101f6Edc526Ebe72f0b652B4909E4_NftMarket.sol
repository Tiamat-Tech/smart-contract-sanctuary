pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract NftMarket is ERC721PresetMinterPauserAutoId {
    constructor() ERC721PresetMinterPauserAutoId("NftMarket", "NMC", "") {
    }
}
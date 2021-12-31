// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract AisthisiToken is ERC721PresetMinterPauserAutoId {

    constructor() ERC721PresetMinterPauserAutoId("AisthisiToken", "AIS", "https://aisthisi.art/metadata/") {}

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
       return string(abi.encodePacked(super.tokenURI(tokenId),".json"));
    }
}
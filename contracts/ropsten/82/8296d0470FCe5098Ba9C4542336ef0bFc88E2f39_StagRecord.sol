// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract StagRecord is ERC721PresetMinterPauserAutoId {

    constructor() ERC721PresetMinterPauserAutoId("StagRecord", "STAG", "https://stag-records-api.azurewebsites.net/MetaData/Record/") {}

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
       return string(abi.encodePacked(super.tokenURI(tokenId)));
    }
}
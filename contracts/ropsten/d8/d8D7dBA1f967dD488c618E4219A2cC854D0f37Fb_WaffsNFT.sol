// contracts/WaffsToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract WaffsNFT is ERC721PresetMinterPauserAutoId {
    constructor()
        ERC721PresetMinterPauserAutoId("WaffsTest", "NFT", "https://raw.githubusercontent.com/CryptoTokens/nft-meta/main/meta.json")
    {
    }
}
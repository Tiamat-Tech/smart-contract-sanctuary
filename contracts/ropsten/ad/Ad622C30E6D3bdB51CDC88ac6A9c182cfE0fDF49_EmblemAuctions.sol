// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./EmblemAuctionsWithPromos.sol";

contract EmblemAuctions is EmblemAuctionsWithPromos {
    // Delegate constructor
    constructor(address _nftAddr, uint256 _cut)
        EmblemAuctionsWithPromos(_nftAddr, _cut)
    {}
}
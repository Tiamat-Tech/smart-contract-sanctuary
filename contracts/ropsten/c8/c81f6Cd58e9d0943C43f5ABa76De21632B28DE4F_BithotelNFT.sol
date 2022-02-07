// SPDX-License-Identifier: MIT OR Apache-2.0
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.0;

import "./base/NFT721.sol";

contract BithotelNFT is NFT721 {
    function getVersion() public pure returns (uint256) {
        return 1;
    }
}
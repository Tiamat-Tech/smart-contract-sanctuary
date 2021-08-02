// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.0;

import "./base/NFT721.sol";


contract PocmonNFT is NFT721 {
    function getVersion() public pure returns (uint256) {
        return 1;
    }
}
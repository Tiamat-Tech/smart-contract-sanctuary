// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "../TroveLinkMultiSignatureWallet.sol";

contract TestnetTroveLinkMultiSignatureWallet is TroveLinkMultiSignatureWallet {

    function proposalDuration() public pure override(TroveLinkMultiSignatureWallet) returns (uint256) {
        return 10 minutes;
    }
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "ECDSA.sol";
import "Context.sol";

contract TestPack is Context {
    using ECDSA for bytes32;


    function testSigner(address minter, uint256 amount, uint256 slotId, bytes memory signature) public pure returns (address) {
        return _getSigner(keccak256(abi.encodePacked(minter, amount, slotId)), signature);

    }

    function _getSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        return hash.toEthSignedMessageHash().recover(signature);
    }
}
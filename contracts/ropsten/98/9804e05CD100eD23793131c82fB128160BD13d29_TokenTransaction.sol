// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Utils {
    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) internal pure returns (address){
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v){
        require(sig.length == 65, "invalid signature length");
        assembly {
        /*
        First 32 bytes stores the length of the signature
        add(sig, 32) = pointer of sig + 32
        effectively, skips first 32 bytes of signature
        mload(p) loads next 32 bytes starting at the memory address p into memory
        */
        // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
        // second 32 bytes
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
        // implicitly return (r, s, v)
    }

    function firstIndexOf(address[] storage array, address key) internal view returns (bool, uint) {
        if (array.length == 0) {
            return (false, 0);
        }
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == key) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function removeByValue(address[] storage array, address value) internal {
        uint index;
        bool isIn;
        (isIn, index) = firstIndexOf(array, value);
        if (isIn) {
            removeByIndex(array, index);
        }
    }

    function removeByIndex(address[] storage array, uint index) internal {
        require(index < array.length, "ArrayForUint256: index out of bounds");
        while (index < array.length - 1) {
            array[index] = array[index + 1];
        }
        array.pop();
    }
}
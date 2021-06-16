// BeyondFaces.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721Tradable.sol";

/**
 * @title BeyondFaces
 */
contract BeyondFaces is ERC721Tradable {
    constructor(address _proxyRegistryAddress)
    ERC721Tradable("BeyondFaces", "FACE", _proxyRegistryAddress){}

    function baseTokenURI() override public pure returns (string memory) {
        return "https://api.beyondfaces.io/face/";
    }

    function contractURI() public pure returns (string memory) {
        return "https://api.beyondfaces.io/contract";
    }
}
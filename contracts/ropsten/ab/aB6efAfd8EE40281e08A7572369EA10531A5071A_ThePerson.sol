// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721Tradable.sol";

/**
 * @title OpenSpace
 * OpenSpace - a contract for super stars.
 */
contract ThePerson is ERC721Tradable {
    constructor(address _proxyRegistryAddress, address _saleContractAddress)
    ERC721Tradable("ThePerson", "TP", _proxyRegistryAddress, _saleContractAddress) {}

    function baseTokenURI() override public pure returns (string memory) {
        return "https://romanow.xyz/api/stars/tokens/";
    }

    function contractURI() public pure returns (string memory) {
        return "https://romanow.xyz/api/stars/tokens/";
    }
}
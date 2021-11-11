// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./Base64Metadata.sol";

/**
 * @title TacticalTangrams
 * TacticalTangrams - a contract for Tactical Tangrams tans and tangram sets.
 */
contract TacticalTangrams is /* ERC721Tradable,*/ Base64Metadata {
    constructor()//address _proxyRegistryAddress)
        //ERC721Tradable("TacticalTangrams", "TATA", _proxyRegistryAddress)
    {}

    // function baseTokenURI() override public pure returns (string memory) {
    //     return "https://creatures-api.opensea.io/api/creature/";
    // }
}
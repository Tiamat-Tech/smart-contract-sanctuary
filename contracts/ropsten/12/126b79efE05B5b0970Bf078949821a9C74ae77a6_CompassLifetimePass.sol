// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721Tradable.sol";

/**
 * @title CompassLifetimePass
 * CompassLifetimePass - a contract for Compass.art lifetime passes.
 */
contract CompassLifetimePass is ERC721Tradable {
    constructor(string memory name, string memory symbol, uint256 reserveSupply)
        ERC721Tradable(name, symbol, reserveSupply)
    {}

    function baseTokenURI() override public pure returns (string memory) {
        return "https://creatures-api.opensea.io/api/creature/";
    }

    function contractURI() public pure returns (string memory) {
        return "https://creatures-api.opensea.io/contract/opensea-creatures";
    }
}
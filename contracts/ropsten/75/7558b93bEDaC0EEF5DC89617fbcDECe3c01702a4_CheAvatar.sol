// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./MitaAvatar.sol";

contract CheAvatar is MitaAvatar {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() MitaAvatar("Che Avatar", "CHE") {}

    function baseTokenURI() public pure override returns (string memory) {
        return "https://mita-api.starsuper.net/series/che";
    }

    function contractURI() public pure returns (string memory) {
        return "https://mita-api.starsuper.net/series/che";
    }
}
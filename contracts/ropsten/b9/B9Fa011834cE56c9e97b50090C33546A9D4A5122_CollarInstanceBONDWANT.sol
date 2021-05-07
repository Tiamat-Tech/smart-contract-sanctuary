//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Collar.sol";

contract CollarInstanceBONDWANT is Collar {
    function address_bond() public pure override returns (address) {
        return 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    }

    function address_want() public pure override returns (address) {
        return 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    }

    function address_call() public pure override returns (address) {
        return 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707;
    }

    function address_coll() public pure override returns (address) {
        return 0x0165878A594ca255338adfa4d48449f69242Eb8F;
    }

    function expiry_time() public pure override returns (uint256) {
        return 4000000000;
    }
}
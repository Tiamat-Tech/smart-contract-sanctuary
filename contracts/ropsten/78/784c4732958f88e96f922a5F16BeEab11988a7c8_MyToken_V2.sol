// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./Versionable.sol";
import "./MyToken.sol";

/**
 * @title MyToken_V2
 * @dev Sample version 2
 */
contract MyToken_V2 is MyToken, Versionable {
    function initialize(int8 _version) initializer public {
        __Versionable_init(_version);
    }
}
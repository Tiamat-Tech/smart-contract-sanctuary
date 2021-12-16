// contracts/DecentralizedIdentityRegistry.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DecentralizedIdentityToken.sol";

contract DecentralizedIdentityRegistry {

    DecentralizedIdentityToken public did;

    constructor(DecentralizedIdentityToken _did) {
      did = _did;
    }

    function register() public {
      did.issue(msg.sender);
    }

}
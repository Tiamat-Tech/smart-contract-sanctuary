// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./GhostBridge.sol";
import "./token/IERC20.sol";

contract GhostBridgeUsdt is GhostBridge {
    constructor(IERC20 _token) GhostBridge(_token) {}
}
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./BasicKishiDistributor.sol";

contract tKishiKishiDistributor is BasicKishiDistributor {
    constructor (IERC20 _bone) BasicKishiDistributor(_bone) public {}
}
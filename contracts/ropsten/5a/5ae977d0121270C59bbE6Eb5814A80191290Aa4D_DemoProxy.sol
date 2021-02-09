// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract DemoProxy is TransparentUpgradeableProxy {
    address j = 0x0794670877f0509D23816cbE34a65083A7D70938;

    address v = 0x2AF142784eD8f0ED17101bb091D58519560825e3;

    constructor()
        public
        payable
        TransparentUpgradeableProxy(
            j,
            v,
            abi.encodeWithSignature("initialize(uint256)", 30)
        )
    {}
}
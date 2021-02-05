// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract DemoProxy is TransparentUpgradeableProxy {
    address j = 0x4D0c54E68Ba1e77F183a7853d3B0c38904a2262A;

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
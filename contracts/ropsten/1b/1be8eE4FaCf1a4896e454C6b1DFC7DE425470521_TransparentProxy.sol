// SPDX-License-Identifier: MIT
// @unsupported: ovm
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract TransparentProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data) public TransparentUpgradeableProxy(_logic, admin_, _data){}
}
pragma solidity 0.8.0;

import "../Proxy.sol";
import "../MiniOwnable.sol";

contract MinimalProxy is OwnableMini, Proxy {

    address public implementation;

    constructor(address impl) {
        implementation = impl;
        _owner = msg.sender;
    }

    function _implementation() override(Proxy) internal view returns(address) {
        return implementation;
    }
}
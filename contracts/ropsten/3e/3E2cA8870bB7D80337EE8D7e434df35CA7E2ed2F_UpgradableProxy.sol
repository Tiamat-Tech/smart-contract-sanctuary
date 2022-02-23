// SPDX-License-Identifier: MIT 

pragma solidity ^0.7.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/utils/Address.sol";
import "./Proxy.sol";

contract UpgradableProxy is Proxy {
    
    bytes32 constant IMPLEMENTATION_SLOT = keccak256("proxy.upgradable.pattern.test.mine");

    
    event Upgraded(address indexed implementation);
    
    constructor(address _logic) {
        _setImplementation(_logic);
    }

    function getImplementation() public view returns (address) {
        return _implementation();
    }
    
    function _implementation() internal view override returns (address) {
        address impl;
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
        return impl;
    }
    
    function _upgradeTo(address newImplementation) internal virtual {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
    
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "address not a contract");
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
    
    function _beforeFallback() internal virtual override {
        super._beforeFallback();
    }
}
//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
//import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "./proxy.sol";
import "./ownable.sol";


contract upgradableproxy is Proxy, Ownable {
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    event Upgraded(address indexed implementation);

    // constructor (address newImplementation, bytes memory data) {
    //     _setImplementation(newImplementation);
    //     Address.functionDelegateCall(newImplementation, data);
    // }
    
    function initialize(address implementation, bytes memory data) external {
        require(_implementation() == address(0));
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        _setImplementation(implementation);
        if (data.length > 0) {
            Address.functionDelegateCall(implementation, data);
        }
    }

    function getImplementation() external view returns (address){
        return _implementation();
    }

    function _getImplementation() internal view returns (address r) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly{
            r := sload(slot)
        }
        
        //return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly{
            sstore(slot, newImplementation)
        }
        //StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    function _implementation() internal view override returns (address){
        return _getImplementation();
    }

    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    function upgradeTo(address newImplementation) external {
        _upgradeTo(newImplementation);
    }

    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) internal {
        _upgradeTo(newImplementation);
        Address.functionDelegateCall(newImplementation, data);
    }
}
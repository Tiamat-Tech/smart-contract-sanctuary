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
    
    function initialize(address implementation, bytes memory data) external {
        require(_implementation() == address(0));
        _setImplementation(implementation);
        if (data.length > 0) {
            Address.functionDelegateCall(implementation, data);
        }
    }

    function getImplementation() external view returns (address){
        return _implementation();
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
    }

    function _implementation() internal view override returns (address addr){
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly{
            addr := sload(slot)
        }
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
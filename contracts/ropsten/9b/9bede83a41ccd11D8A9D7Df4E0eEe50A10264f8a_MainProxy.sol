pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title A transparent EIP1967 based upgradable proxy for Main.
 * @dev This contract allows for upgrades of Main contract and manages balances for DeFire users.
 *
 * Take a look at https://docs.openzeppelin.com/contracts/3.x/api/proxy#TransparentUpgradeableProxy[this link] for more details about the mechanics of the underlying contract architecture.
 */
contract MainProxy is TransparentUpgradeableProxy {
    mapping(address => bool) internal previousVersions;

    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) payable TransparentUpgradeableProxy(_logic, admin_, _data) {
        previousVersions[_logic] = true;
    }

    /**
     * @notice Returns an address of the current implementation.
     *
     * @return An address of the current implementation.
     */
    function getImplementation() external view returns (address) {
        return _implementation();
    }

    /**
     * @notice Checks if certain address is an active implementation that can be used.
     *
     * @return Returns true if provided address is an active implementation, else returns false.
     */
    function isActiveImplementation(address _impl)
        external
        view
        returns (bool)
    {
        return previousVersions[_impl];
    }

    /**
     * @dev Sets new implementation. Must be used instead of 'upgradeTo()' and 'upgradeToAndCall()'! Can only be called by admin.
     * @param _impl An address of new implementation.
     */
    function newImplementation(address _impl) external ifAdmin {
        _upgradeToAndCall(_impl, bytes(""), false);

        previousVersions[_impl] = true;
    }

    /**
     * @dev Revokes previous implementation, due to it being unsecure, inefficient, etc.
     * @param _impl An address of the implementation to be revoked.
     * @param _sub Substitute address, if the version being revoked is the newest one.
     */
    function revokeImplementation(address _impl, address _sub)
        external
        ifAdmin
    {
        if (_implementation() == _impl) {
            _upgradeToAndCall(_sub, bytes(""), false);

            previousVersions[_sub] = true;
        }

        previousVersions[_impl] = false;
    }

	function _fallback() internal override {
        _delegate(_implementation());
    }
}
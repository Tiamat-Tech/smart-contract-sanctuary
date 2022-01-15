pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract AccessControlList is AccessControl {

    bytes32 public constant CONTROL_LIST_ADMIN_ROLE = keccak256("CONTROL_LIST_ADMIN_ROLE");
    bytes32 public constant BRIDGE_CALLER_ROLE = keccak256("BRIDGE_CALLER_ROLE");
    bytes32 public constant BRIDGE_CALLER_GRANTING_ROLE = keccak256("BRIDGE_CALLER_GRANTING_ROLE");
    bytes32 public constant BRIDGE_DEFAULT_ADMIN_ROLE = keccak256("BRIDGE_DEFAULT_ADMIN_ROLE");
    bytes32 public constant SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE = keccak256("SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE");

    constructor() {
        _setupRole(CONTROL_LIST_ADMIN_ROLE, msg.sender);
        _setupRole(SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE, msg.sender);
    }
    function checkRole(bytes32 role, address account) external view {
        return _checkRole(role, account);
    }

    function grantBridgeCallerRole(address addr) external onlyRole(BRIDGE_CALLER_GRANTING_ROLE) {
        _setupRole(BRIDGE_CALLER_ROLE, addr);
    }

    function grantBridgeCallerGrantingRole(address addr) external onlyRole(CONTROL_LIST_ADMIN_ROLE) {
        _setupRole(BRIDGE_CALLER_GRANTING_ROLE, addr);
    }

    function grantRole(address addr, bytes32 role) external onlyRole(CONTROL_LIST_ADMIN_ROLE) {
        _setupRole(role, addr);
    }
}
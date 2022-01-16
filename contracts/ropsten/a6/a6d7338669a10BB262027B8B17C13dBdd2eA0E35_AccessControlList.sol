pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract AccessControlList is AccessControl {

    bytes32 public constant CONTROL_LIST_ADMIN_ROLE = keccak256("CONTROL_LIST_ADMIN_ROLE");
    bytes32 public constant BRIDGE_CALLER_ROLE = keccak256("BRIDGE_CALLER_ROLE");
    bytes32 public constant BRIDGE_CALLER_GRANTING_ROLE = keccak256("BRIDGE_CALLER_GRANTING_ROLE");
    bytes32 public constant BRIDGE_DEFAULT_ADMIN_ROLE = keccak256("BRIDGE_DEFAULT_ADMIN_ROLE");
    bytes32 public constant SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE = keccak256("SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE");

    constructor(address admin) {
        _setupRole(CONTROL_LIST_ADMIN_ROLE, admin);
        _setupRole(SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE, admin);
        _setRoleAdmin(SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE, CONTROL_LIST_ADMIN_ROLE);
        _setRoleAdmin(BRIDGE_CALLER_GRANTING_ROLE, CONTROL_LIST_ADMIN_ROLE);
        _setRoleAdmin(BRIDGE_DEFAULT_ADMIN_ROLE, CONTROL_LIST_ADMIN_ROLE);
        _setRoleAdmin(BRIDGE_CALLER_ROLE, BRIDGE_CALLER_GRANTING_ROLE);
    }

    function checkRole(bytes32 role, address account) external view {
        return _checkRole(role, account);
    }

    function grantBridgeCallerRole(address addr) external onlyRole(BRIDGE_CALLER_GRANTING_ROLE) {
        grantRole(BRIDGE_CALLER_ROLE, addr);
    }

    function grantBridgeCallerGrantingRole(address addr) external onlyRole(CONTROL_LIST_ADMIN_ROLE) {
        grantRole(BRIDGE_CALLER_GRANTING_ROLE, addr);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyRole(CONTROL_LIST_ADMIN_ROLE){
        _setRoleAdmin(role, adminRole);
    }
}
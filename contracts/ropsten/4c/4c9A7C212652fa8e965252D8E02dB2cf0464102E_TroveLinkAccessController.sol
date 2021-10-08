// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./interfaces/ITroveLinkAccessController.sol";

contract TroveLinkAccessController is ITroveLinkAccessController, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address private _controller;
    bool private _initialized;
    EnumerableSet.Bytes32Set private _roles;
    mapping(bytes32 => EnumerableSet.AddressSet) private _roleMembers;

    function controller() public view returns (address) {
        return _controller;
    }

    function initialized() public view returns (bool) {
        return _initialized;
    }

    function roleCount() external view override(ITroveLinkAccessController) returns (uint256) {
        return _roles.length();
    }

    function hasRole(
        bytes32 role_,
        address account_
    ) external view override(ITroveLinkAccessController) returns (bool) {
        return _roleMembers[role_].contains(account_);
    }

    function role(uint256 index_) external view override(ITroveLinkAccessController) returns (bytes32) {
        return _roles.at(index_);
    }

    function roleMember(
        bytes32 role_,
        uint256 index_
    ) external view override(ITroveLinkAccessController) returns (address) {
        return _roleMembers[role_].at(index_);
    }

    function roleMemberCount(bytes32 role_) external view override(ITroveLinkAccessController) returns (uint256) {
        return _roleMembers[role_].length();
    }

    function addRole(bytes32 role_) external override(ITroveLinkAccessController) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == _controller, "Invalid sender");
        require(!_roles.contains(role_), "Role already exist");
        _addRole(role_);
        return true;
    }

    function grantRole(
        bytes32 role_,
        address account_
    ) external override(ITroveLinkAccessController) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == _controller, "Invalid sender");
        require(_roles.contains(role_), "Role not exist");
        require(!_roleMembers[role_].contains(account_), "Account already role member");
        _roleMembers[role_].add(account_);
        emit RoleGranted(role_, account_);
        return true;
    }

    function removeRole(bytes32 role_) external override(ITroveLinkAccessController) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == _controller, "Invalid sender");
        require(_roles.contains(role_), "Role not exist");
        require(_roleMembers[role_].length() == 0, "Role has members");
        _roles.remove(role_);
        emit RoleRemoved(role_);
        return true;
    }

    function revokeRole(
        bytes32 role_,
        address account_
    ) external override(ITroveLinkAccessController) returns (bool) {
        address sender = msg.sender;
        require(_initialized, "Not initialized");
        require(sender == _controller || sender == account_, "Invalid sender");
        require(_roles.contains(role_), "Role not exist");
        require(_roleMembers[role_].contains(account_), "Account is not role member");
        _roleMembers[role_].remove(account_);
        emit RoleRevoked(role_, account_);
        return true;
    }

    function initialize(
        address controller_,
        bytes32[] memory roles_
    ) public initializer() returns (bool) {
        require(!_initialized, "Already initialized");
        require(controller_ != address(0), "Controller is zero address");
        _controller = controller_;
        for (uint256 i = 0; i < roles_.length; i++) {
            _addRole(roles_[i]);
        }
        _initialized = true;
        emit Initialized(controller_, roles_);
        return true;
    }

    function _addRole(bytes32 role_) private {
        require(role_ != bytes32(0), "Role is zero bytes");
        if (_roles.add(role_)) emit RoleAdded(role_);
    }
}
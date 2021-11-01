// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./interfaces/ITroveLinkAccessController.sol";

/**
 * @title contract module that provides a role-jurisdiction-based access control mechanism;
 * This module contains role/jurisdiction/access management methods
 */
contract TroveLinkAccessController is ITroveLinkAccessController, Initializable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address private _controller;
    bool private _initialized;
    EnumerableSet.Bytes32Set private _jurisdictions;
    EnumerableSet.Bytes32Set private _roles;
    mapping(bytes32 => mapping(bytes32 => mapping(address => bytes32))) private _attachments;
    mapping(bytes32 => mapping(bytes32 => EnumerableSet.AddressSet)) private _jurisdictionMembers;
    mapping(bytes32 => uint256) private _jurisdictionMembersCount;
    mapping(bytes32 => string) private _jurisdictionName;
    mapping(bytes32 => mapping(address => uint256)) private _roleJurisdictionsCount;
    mapping(bytes32 => EnumerableSet.AddressSet) private _roleMembers;
    mapping(bytes32 => string) private _roleName;

    /**
     * @notice Returns controller address
     */
    function controller() public view returns (address) {
        return _controller;
    }

    /**
     * @notice Returns contract initialization status
     */
    function initialized() public view returns (bool) {
        return _initialized;
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function jurisdictionCount() external view override(ITroveLinkAccessController) returns (uint256) {
        return _jurisdictions.length();
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function roleCount() external view override(ITroveLinkAccessController) returns (uint256) {
        return _roles.length();
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function attachment(
        bytes32 role_,
        bytes32 jurisdiction_,
        address account_
    ) external view override(ITroveLinkAccessController) returns (bytes32) {
        return _attachments[role_][jurisdiction_][account_];
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function hasRole(
        bytes32 role_,
        address account_
    ) external view override(ITroveLinkAccessController) returns (bool) {
        return _roleMembers[role_].contains(account_);
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function hasJurisdiction(
        bytes32 role_,
        bytes32 jurisdiction_,
        address account_
    ) external view override(ITroveLinkAccessController) returns (bool) {
        return _jurisdictionMembers[role_][jurisdiction_].contains(account_);
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function isJurisdiction(bytes32 jurisdiction_) external view override(ITroveLinkAccessController) returns (bool) {
        return _jurisdictions.contains(jurisdiction_);
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function isRole(bytes32 role_) external view override(ITroveLinkAccessController) returns (bool) {
        return _roles.contains(role_);
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function jurisdiction(uint256 index_) external view override(ITroveLinkAccessController) returns (bytes32) {
        return _jurisdictions.at(index_);
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function jurisdictionMember(
        bytes32 role_,
        bytes32 jurisdiction_,
        uint256 index_
    ) external view override(ITroveLinkAccessController) returns (address) {
        return _jurisdictionMembers[role_][jurisdiction_].at(index_);
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function jurisdictionMemberCount(
        bytes32 jurisdiction_
    ) external view override(ITroveLinkAccessController) returns (uint256) {
        return _jurisdictionMembersCount[jurisdiction_];
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function jurisdictionMemberCount(
        bytes32 role_,
        bytes32 jurisdiction_
    ) external view override(ITroveLinkAccessController) returns (uint256) {
        return _jurisdictionMembers[role_][jurisdiction_].length();
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function jurisdictionName(
        bytes32 jurisdiction_
    ) external view override(ITroveLinkAccessController) returns (string memory) {
        return _jurisdictionName[jurisdiction_];
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function role(uint256 index_) external view override(ITroveLinkAccessController) returns (bytes32) {
        return _roles.at(index_);
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function roleJurisdictionsCount(
        address account_, bytes32 role_
    ) external view override(ITroveLinkAccessController) returns (uint256) {
        return _roleJurisdictionsCount[role_][account_];
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function roleMember(
        bytes32 role_,
        uint256 index_
    ) external view override(ITroveLinkAccessController) returns (address) {
        return _roleMembers[role_].at(index_);
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function roleMemberCount(bytes32 role_) external view override(ITroveLinkAccessController) returns (uint256) {
        return _roleMembers[role_].length();
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     */
    function roleName(bytes32 role_) external view override(ITroveLinkAccessController) returns (string memory) {
        return _roleName[role_];
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     * @param name_ Must be not already added
     */
    function addJurisdiction(string memory name_) external override(ITroveLinkAccessController) returns (bool) {
        bytes32 jurisdiction_ = keccak256(abi.encode(name_));
        require(_initialized, "Not initialized");
        require(msg.sender == _controller, "Invalid sender");
        require(!_jurisdictions.contains(jurisdiction_), "Jurisdiction already exist");
        _addJurisdiction(jurisdiction_, name_);
        return true;
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     * @param name_ Must be not already added
     */
    function addRole(string memory name_) external override(ITroveLinkAccessController) returns (bool) {
        bytes32 role_ = keccak256(abi.encode(name_));
        require(_initialized, "Not initialized");
        require(msg.sender == _controller, "Invalid sender");
        require(!_roles.contains(role_), "Role already exist");
        _addRole(role_, name_);
        return true;
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     * @param role_ Must be an existing role
     * @param jurisdiction_ Must be an existing jurisdiction
     */
    function grantAccess(
        address account_,
        bytes32 role_,
        bytes32 jurisdiction_,
        bytes32 attachment_
    ) external override(ITroveLinkAccessController) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == _controller, "Invalid sender");
        require(_roles.contains(role_), "Role not exist");
        require(_jurisdictions.contains(jurisdiction_), "Jurisdiction not exist");
        _grantAccess(account_, role_, jurisdiction_, attachment_);
        return true;
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     * @param jurisdiction_ Must be an existing jurisdiction
     * @param jurisdiction_ Jurisdiction members count must be equal to 0
     */
    function removeJurisdiction(bytes32 jurisdiction_) external override(ITroveLinkAccessController) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == _controller, "Invalid sender");
        require(_jurisdictions.contains(jurisdiction_), "Jurisdiction not exist");
        require(_jurisdictionMembersCount[jurisdiction_] == 0, "Jurisdiction has members");
        string memory name_ = _jurisdictionName[jurisdiction_];
        _jurisdictions.remove(jurisdiction_);
        delete _jurisdictionName[jurisdiction_];
        emit JurisdictionRemoved(jurisdiction_, name_);
        return true;
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     * @param role_ Must be an existing role
     * @param role_ Role members count must be equal to 0
     */
    function removeRole(bytes32 role_) external override(ITroveLinkAccessController) returns (bool) {
        require(_initialized, "Not initialized");
        require(msg.sender == _controller, "Invalid sender");
        require(_roles.contains(role_), "Role not exist");
        require(_roleMembers[role_].length() == 0, "Role has members");
        string memory name_ = _roleName[role_];
        _roles.remove(role_);
        delete _roleName[role_];
        emit RoleRemoved(role_, name_);
        return true;
    }

    /**
     * @inheritdoc ITroveLinkAccessController
     * @param role_ Must be an existing role
     * @param jurisdiction_ Must be an existing jurisdiction
     * @param account_ Must be a role_ jurisdiction_ member
     */
    function revokeAccess(
        address account_,
        bytes32 role_,
        bytes32 jurisdiction_
    ) external override(ITroveLinkAccessController) returns (bool) {
        address sender = msg.sender;
        require(_initialized, "Not initialized");
        require(sender == _controller || sender == account_, "Invalid sender");
        require(_roles.contains(role_), "Role not exist");
        require(_jurisdictions.contains(jurisdiction_), "Jurisdiction not exist");
        require(_jurisdictionMembers[role_][jurisdiction_].contains(account_), "Account not jurisdiction role member");
        uint256 roleJurisdictionsCount_ = _roleJurisdictionsCount[role_][account_].sub(1);
        _jurisdictionMembers[role_][jurisdiction_].remove(account_);
        _jurisdictionMembersCount[jurisdiction_] = _jurisdictionMembersCount[jurisdiction_].sub(1);
        _roleJurisdictionsCount[role_][account_] = roleJurisdictionsCount_;
        _attachments[role_][jurisdiction_][account_] = bytes32(0);
        if (roleJurisdictionsCount_ == 0) _roleMembers[role_].remove(account_);
        emit AccessRevoked(account_, role_, jurisdiction_);
        return true;
    }

    /**
     * @notice Method for contract initializing
     * @dev For success works contract must not be already initialized
     * Member parameters lengths should be equals
     * Can emits a multiple ({RoleAdded}, {JurisdictionAdded}, {AccessGranted}) events
     * @param controller_ Controller address
     * @param controller_ Must not be equal to zero address
     * @param roles_ Initial roles names
     * @param jurisdictions_ Initial jurisdictions names
     * @param members_ Initial members addresses
     * @param memberRoles_ Iniital members roles
     * @param memberJurisdictions_ Initial members jurisdictions
     * @return boolean value indicating whether the operation succeded
     */
    function initialize(
        address controller_,
        string[] memory roles_,
        string[] memory jurisdictions_,
        address[] memory members_,
        bytes32[] memory memberRoles_,
        bytes32[] memory memberJurisdictions_
    ) public initializer() returns (bool) {
        require(!_initialized, "Already initialized");
        require(controller_ != address(0), "Controller is zero address");
        require(
            members_.length == memberRoles_.length && members_.length == memberJurisdictions_.length,
            "Invalid member params length"
        );
        _controller = controller_;
        uint256 iterator;
        for (iterator = 0; iterator < roles_.length; iterator++) {
            _addRole(keccak256(abi.encode(roles_[iterator])), roles_[iterator]);
        }
        for (iterator = 0; iterator < jurisdictions_.length; iterator++) {
            _addJurisdiction(keccak256(abi.encode(jurisdictions_[iterator])), jurisdictions_[iterator]);
        }
        for (iterator = 0; iterator < members_.length; iterator++) {
            bytes32 role_ = memberRoles_[iterator];
            bytes32 jurisdiction_ = memberJurisdictions_[iterator];
            require(_roles.contains(role_), "Role not exist");
            require(_jurisdictions.contains(jurisdiction_), "Jurisdiction not exist");
            _grantAccess(members_[iterator], role_, jurisdiction_, bytes32(0));
        }
        _initialized = true;
        return true;
    }

    /**
     * @dev Private method for adding a Jurisdiction
     * Can emits a {JurisdictionAdded} event
     * @param jurisdiction_ Jurisdiction hash
     * @param jurisdiction_ Must be a non-zero hash
     * @param name_ Jurisdiction name
     */
    function _addJurisdiction(bytes32 jurisdiction_, string memory name_) private {
        require(jurisdiction_ != bytes32(0), "Jurisdiction is zero bytes");
        if (_jurisdictions.add(jurisdiction_)) {
            _jurisdictionName[jurisdiction_] = name_;
            emit JurisdictionAdded(jurisdiction_, name_);
        }
    }

    /**
     * @dev Private method for adding a role
     * Can emits a {RoleAdded} event
     * @param role_ Role hash
     * @param role_ Must be a non-zero hash
     * @param name_ Role name
     */
    function _addRole(bytes32 role_, string memory name_) private {
        require(role_ != bytes32(0), "Role is zero bytes");
        if (_roles.add(role_)) {
            _roleName[role_] = name_;
            emit RoleAdded(role_, name_);
        }
    }

    /**
     * @dev Private method for access granting
     * Emits a {AccessGranted} event
     * @param account_ Account address
     * @param role_ Role hash
     * @param jurisdiction_ Jurisdiction hash
     * @param attachment_ Attachment hash
     */
    function _grantAccess(
        address account_,
        bytes32 role_,
        bytes32 jurisdiction_,
        bytes32 attachment_
    ) private {
        if (!_jurisdictionMembers[role_][jurisdiction_].contains(account_)) {
            _roleMembers[role_].add(account_);
            _jurisdictionMembers[role_][jurisdiction_].add(account_);
            _jurisdictionMembersCount[jurisdiction_] = _jurisdictionMembersCount[jurisdiction_].add(1);
            _roleJurisdictionsCount[role_][account_] = _roleJurisdictionsCount[role_][account_].add(1);
        }
        _attachments[role_][jurisdiction_][account_] = attachment_;
        emit AccessGranted(account_, role_, jurisdiction_, attachment_);
    }
}
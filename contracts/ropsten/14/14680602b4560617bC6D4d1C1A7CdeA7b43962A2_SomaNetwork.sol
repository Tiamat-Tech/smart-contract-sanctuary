// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "./ISomaNetwork.sol";
import "./utils/INetworkAccess.sol";
import "../../utils/StringHelper.sol";
import "../../utils/access/ProposedOwnableUpgradeable.sol";

contract SomaNetwork is ISomaNetwork, ProposedOwnableUpgradeable, AccessControlUpgradeable, PausableUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    struct NetworkAccess {
        bool approved;
        uint256 approvedAt;
        address approvedBy;
    }

    event NetworkKeyUpdated(bytes32 key, address prevAddress, address newAddress);
    event NetworkAccessApproved(address indexed account, address approvedBy);
    event NetworkAccessRevoked(address indexed account, address revokedBy);

    bytes32 public constant override PAUSE_ROLE = keccak256("SomaNetwork:pause");
    bytes32 public constant override ASSIGN_KEY_ROLE = keccak256("SomaNetwork:assign_Key");
    bytes32 public constant override NETWORK_MANAGER_ROLE = keccak256('SomaNetwork:manager');

    bytes32 public constant override BASIC_ROLE_MANAGER = keccak256("SomaNetwork:base_role_manager");
    bytes32 public constant override APPROVE_ACCESS_ROLE = keccak256("SomaNetwork:approve_access");
    bytes32 public constant override LOCAL_REVOKE_ACCESS_ROLE = keccak256("SomaNetwork:local_revoke_access");
    bytes32 public constant override GLOBAL_REVOKE_ACCESS_ROLE = keccak256("SomaNetwork:global_revoke_access");

    mapping (bytes32 => address) private _routing;
    mapping (address => bytes32) private _keys;
    mapping (address => EnumerableSetUpgradeable.Bytes32Set) private _roles;
    mapping (bytes32 => EnumerableSetUpgradeable.AddressSet) private _accounts;
    mapping (address => NetworkAccess) private _networkAccess;

    uint256 public networkSize;

    function initialize(address owner_) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __Ownable_init();

        // define the unique permissions of items inside the network
        // TODO should this role manage itself? if all is lost then it is gg I guess
        _setRoleAdmin(BASIC_ROLE_MANAGER, BASIC_ROLE_MANAGER);

        _setRoleAdmin(LOCAL_REVOKE_ACCESS_ROLE, BASIC_ROLE_MANAGER);
        _setRoleAdmin(GLOBAL_REVOKE_ACCESS_ROLE, BASIC_ROLE_MANAGER);
        _setRoleAdmin(APPROVE_ACCESS_ROLE, BASIC_ROLE_MANAGER);

        _transferOwnership(owner_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ISomaNetwork).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual override(ISomaNetwork, ProposedOwnableUpgradeable) returns (address) {
        return super.owner();
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function paused() public view virtual override(IPausable, PausableUpgradeable) returns (bool) {
        return super.paused();
    }

    function keyOf(address account) public override onlyRole(ASSIGN_KEY_ROLE) view returns (bytes32) {
        return _keys[account];
    }

    function get(bytes32 key) external override whenNotPaused view returns (address) {
        if (_routing[key] == address(0)) {
            revert(
                string(
                    abi.encodePacked(
                        "SomaNetwork: key '",
                        StringHelper.fromBytes32(key),
                        "' does not exist on this network."
                    )
                )
            );
        }

        return _routing[key];
    }

    function rolesOf(address account) public view override returns (bytes32[] memory) {
        return _roles[account]._inner._values;
    }

    function accountsOf(bytes32 role) external view override returns (address[] memory) {
        uint256 length = _accounts[role].length();
        address[] memory accounts = new address[](length);

        for (uint i = 0; i < length; i++) {
            accounts[i] = _accounts[role].at(i);
        }

        return accounts;
    }

    function access(address account) external view override returns (bool) {
        return _networkAccess[account].approved;
    }

    function pause() external override onlyRole(PAUSE_ROLE) {
        _pause();
    }

    function unpause() external override onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    function add(address target) external override {
        require(target != address(0), 'SomaNetwork: invalid address.');

        if (AddressUpgradeable.isContract(target)) {
            try IERC165(target).supportsInterface(type(INetworkAccess).interfaceId) returns (bool) {

            INetworkAccess networkAccess = INetworkAccess(target);

            bytes32 key = networkAccess.NETWORK_KEY();
            if (key != 0) _assignToKey(key, target);

            _grantRoles(networkAccess.REQUIRED_ROLES(), target);
            (bytes32[][] memory children, bytes32[] memory parents) = networkAccess.PARENT_ROLES();
            _setParentRoles(children, parents);

            networkAccess.addedToNetwork();

            } catch(bytes memory) {}
        }

        _approveAccess(target);
    }

    function remove(address target) external override {
        bytes32 key = _keys[target];

        if (key != 0) _assignToKey(key, address(0));
        _revokeAllRoles(target);
        _revokeAccess(target);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override(AccessControlUpgradeable, IAccessControlUpgradeable) returns (bool) {
        return super.hasRole(role, account) || owner() == account;
    }

    function grantRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable, IAccessControlUpgradeable) {
        super.grantRole(role, account);
        _roles[account].add(role);
        _accounts[role].add(account);
    }

    function revokeRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable, IAccessControlUpgradeable) {
        super.revokeRole(role, account);
        _roles[account].remove(role);
        _accounts[role].remove(account);
    }

    function _approveAccess(address account) private onlyRole(APPROVE_ACCESS_ROLE) whenNotPaused {
        require(account != address(0), 'SomaNetwork: Cannot add a 0 address to the network.');
        require(!_networkAccess[account].approved, 'SomaNetwork: address already has access to this network.');

        _networkAccess[account].approved = true;
        _networkAccess[account].approvedBy = _msgSender();
        _networkAccess[account].approvedAt = block.timestamp;

        networkSize += 1;

        emit NetworkAccessApproved(account, _msgSender());
    }

    function _revokeAccess(address account) private onlyRole(LOCAL_REVOKE_ACCESS_ROLE) whenNotPaused {
        require(_networkAccess[account].approved, 'SomaNetwork: This address is not on the network.');
        require(
            _msgSender() == _networkAccess[account].approvedBy && hasRole(LOCAL_REVOKE_ACCESS_ROLE, account) ||
            hasRole(GLOBAL_REVOKE_ACCESS_ROLE, _msgSender()),
            'SomaNetwork: this account does not have permission to revoke the specified accounts access.'
        );

        delete _networkAccess[account];
        networkSize -= 1;

        emit NetworkAccessRevoked(account, _msgSender());
    }

    function _beforeOwnershipTransfer(address prevOwner, address newOwner) internal override {
        _approveAccess(newOwner);
        _grantRoles(rolesOf(prevOwner), newOwner);

        if (prevOwner != address(0)) {
            _revokeAllRoles(prevOwner);
            _revokeAccess(prevOwner);
        }
    }

    function _revokeAllRoles(address target) private {
        bytes32[] memory roles = rolesOf(target);
        for (uint i = 0; i < roles.length; i++) {
            revokeRole(roles[i], target);
        }
    }

    function _grantRoles(bytes32[] memory roles, address target) private {
        for (uint i = 0; i < roles.length; i++) {
            grantRole(roles[i], target);
        }
    }

    function _setParentRoles(bytes32[][] memory roles, bytes32[] memory parentRoles) private {
        for (uint i = 0; i < roles.length; i++) {
            for (uint j = 0; j < roles[i].length; j++) {
                bytes32 role = roles[i][j];
                // require that the owner of the parent role can move the parent role
                _checkRole(getRoleAdmin(getRoleAdmin(role)), _msgSender());
                _setRoleAdmin(role, parentRoles[i]);
            }
        }
    }

    function _assignToKey(bytes32 key, address target) private onlyRole(ASSIGN_KEY_ROLE) {
        address prevAddress = _routing[key];

        _keys[prevAddress] = 0;
        _routing[key] = target;

        if (target != address(0)) {
            _keys[target] = key;
        }

        emit NetworkKeyUpdated(key, prevAddress, target);
    }
}
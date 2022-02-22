// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0 <0.9.0;

import "./utils/ENSInterfaces.sol";
import "./utils/Payable.sol";
import "./PermissionManagement.sol";

contract MonumentENSRegistrar is IMonumentENSRegistrar, Payable {
    PermissionManagement internal permissionManagement;

    // ============ Immutable Storage ============

    /**
     * The name of the ENS root, e.g. "monument.app".
     * @dev dependency injectable for testnet.
     */
    string public rootName;

    /**
     * The node of the root name (e.g. namehash(monument.app))
     */
    bytes32 public immutable rootNode;

    /**
     * The address of the public ENS registry.
     * @dev Dependency-injectable for testing purposes, but otherwise this is the
     * canonical ENS registry at 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e.
     */
    IENS public immutable ensRegistry;

    /**
     * The address of the MonumentENSResolver.
     */
    IENSResolver public immutable ensResolver;


    // ============ Events ============

    event RootNodeOwnerChange(bytes32 indexed node, address indexed owner);
    event RegisteredENS(address indexed _owner, string _ens);
    event UpdatedENS(address indexed _owner, string _ens);


    // ============ Constructor ============

    /**
     * @notice Constructor that sets the ENS root name and root node to manage.
     * @param rootName_ The root name (e.g. monument.app).
     * @param rootNode_ The node of the root name (e.g. namehash(monument.app)).
     * @param ensRegistry_ The address of the ENS registry
     * @param ensResolver_ The address of the ENS resolver
     * @param _permissionManagementContractAddress The address of the Permission Management Contract
     */
    constructor (
        string memory rootName_,
        bytes32 rootNode_,
        address ensRegistry_,
        address ensResolver_,
        address _permissionManagementContractAddress
    )
    Payable(_permissionManagementContractAddress)
    payable {
        permissionManagement = PermissionManagement(_permissionManagementContractAddress);

        rootName = rootName_;
        rootNode = rootNode_;

        // Registrations are cheaper if these are instantiated.
        ensRegistry = IENS(ensRegistry_);
        ensResolver = IENSResolver(ensResolver_);
    }


    // ============ Registration ============

    /**
     * @notice Assigns an ENS subdomain of the root node to a target address.
     * Registers both the forward. Can only be called by writeToken.
     * @param label_ The subdomain label.
     * @param owner_ The owner of the subdomain.
     */
    function register(string calldata label_, address owner_)
        external
        override
    {
        permissionManagement.moderatorOnlyMethod(msg.sender);

        bytes32 labelNode = keccak256(abi.encodePacked(label_));
        bytes32 node = keccak256(abi.encodePacked(rootNode, labelNode));

        require(
            ensRegistry.owner(node) == address(0),
            "MonumentENSManager: label is already owned"
        );

        // Forward ENS
        ensRegistry.setSubnodeRecord(
            rootNode,
            labelNode,
            owner_,
            address(ensResolver),
            0
        );
        ensResolver.setAddr(node, owner_);

        emit RegisteredENS(owner_, label_);
    }


    // ============ ENS Management ============

    /**
     * @notice This function must be called when the ENSRegistrar contract is replaced
     * and the address of the new ENSRegistrar should be provided.
     * @param _newOwner The address of the new ENS Registrar that will manage the root node.
     */
    function changeRootNodeOwner(address _newOwner)
        external
        override
    {
        permissionManagement.adminOnlyMethod(msg.sender);

        ensRegistry.setOwner(rootNode, _newOwner);
        emit RootNodeOwnerChange(rootNode, _newOwner);
    }


    // ============ ENS Subnode Management ============

    function labelOwner(string calldata label)
        external
        view
        override
        returns (address)
    {
        bytes32 labelNode = keccak256(abi.encodePacked(label));
        bytes32 node = keccak256(abi.encodePacked(rootNode, labelNode));

        return ensRegistry.owner(node);
    }

    function changeLabelOwner(string calldata label_, address newOwner_)
        external
        override
    {
        bytes32 labelNode = keccak256(abi.encodePacked(label_));
        bytes32 node = keccak256(abi.encodePacked(rootNode, labelNode));

        require(
            ensRegistry.owner(node) == msg.sender ||
            permissionManagement.moderators(msg.sender) == true,
            "MonumentENSManager: sender does not own label"
        );

        // Forward ENS
        ensRegistry.setSubnodeRecord(
            rootNode,
            labelNode,
            newOwner_,
            address(ensResolver),
            0
        );
        ensResolver.setAddr(node, newOwner_);

        emit UpdatedENS(
            newOwner_,
            string(abi.encodePacked(label_, ".", rootName))
        );
    }
}
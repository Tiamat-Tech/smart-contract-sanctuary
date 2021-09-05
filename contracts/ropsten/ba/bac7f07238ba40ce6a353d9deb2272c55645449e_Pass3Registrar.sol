// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IENSResolver.sol";
import "./IPass3Registrar.sol";
import "./IENSReverseRegistrar.sol";
import "./IENS.sol";

contract Pass3Registrar is IPass3Registrar, Ownable {
    // ============ Constants ============

    // A map of expiry times
    mapping(bytes32=>uint) avaliableTime;
    /**
     * namehash('addr.reverse')
     */
    bytes32 public constant ADDR_REVERSE_NODE =
        0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    // ============ Immutable Storage ============

    /**
     * The name of the ENS root, e.g. "pass3.me".
     */
    string public rootName;

    /**
     * The node of the root name (e.g. namehash(pass3.me))
     */
    bytes32 public immutable rootNode;

    /**
     * The address of the public ENS registry.
     * ENS registry is at 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e.
     */
    IENS public immutable ensRegistry;

    /**
     * The address of the Pass3Token that gates access to this namespace.
     */
    address public immutable passToken;

    /**
     * The address of the MirrorENSResolver.
     */
    IENSResolver public immutable ensResolver;

    // ============ Mutable Storage ============

    /**
     * Set by anyone to the correct address after configuration,
     * to prevent a lookup on each registration.
     */
    IENSReverseRegistrar public reverseRegistrar;

    address public renameRole;


    // ============ Events ============

    event RootNodeOwnerChange(bytes32 indexed node, address indexed owner);
    event RegisteredENS(address indexed _owner, string _ens);
    event RenameRoleChange(address indexed user);

    // ============ Modifiers ============

    /**
     * @dev Modifier to check whether the `msg.sender` is the MirrorWriteToken.
     * If it is, it will run the function. Otherwise, it will revert.
     */
    modifier onlyPassToken() {
        require(
            msg.sender == passToken,
            "Pass3Registrar: caller is not the Pass3 Token"
        );
        _;
    }

    modifier onlyRenameRole() {
        require(
            msg.sender == renameRole,
            "Pass3Registrar: missing rename role"
        );
        _;
    }

 

    // ============ Constructor ============

    /**
     * @notice Constructor that sets the ENS root name and root node to manage.
     * @param rootName_ The root name (e.g. pass3.me).
     * @param rootNode_ The node of the root name (e.g. namehash(pass3.me)).
     * @param ensRegistry_ The address of the ENS registry
     * @param ensResolver_ The address of the ENS resolver
     * @param passToken_ The address of the Mirror Write Token
     */
    constructor(
        string memory rootName_,
        bytes32 rootNode_,
        address ensRegistry_,
        address ensResolver_,
        address passToken_
    ) {
        rootName = rootName_;
        rootNode = rootNode_;

        passToken = passToken_;

        ensRegistry = IENS(ensRegistry_);
        ensResolver = IENSResolver(ensResolver_);
    }

    // =========== Rename Configuration ============

    function setRenameRole(address user) public onlyOwner{
        renameRole = user;
        emit RenameRoleChange(user);
    }

    // ============ Registration ============

    /**
     * @notice Assigns an ENS subdomain of the root node to a target address.
     * Registers both the forward and reverse ENS. Can only be called by writeToken.
     * @param label_ The subdomain label.
     * @param owner_ The owner of the subdomain.
     */
    function register(string calldata label_, address owner_)
        external
        override
        onlyPassToken
    {
        
        bytes32 labelNode = keccak256(abi.encodePacked(label_));
        bytes32 node = keccak256(abi.encodePacked(rootNode, labelNode));
        string memory name = string(abi.encodePacked(label_, ".", rootName));
        bytes32 reverseNode = reverseRegistrar.node(owner_);
        require(
            ensRegistry.owner(node) == address(0),
            "Pass3Registrar: label is already owned"
        );

        require(avaliableTime[node] < block.timestamp, 
            "Pass3Registrar: label is not avaliable now");
        
        require(
            bytes(ensResolver.name(reverseNode)).length == 0,            
            "Pass3Registrar: pass name already has picked"
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

        // Reverse ENS
        ensResolver.setName(reverseNode, name);

        emit RegisteredENS(owner_, name);
    }



    function rename(string calldata oldLabel_, string calldata newLabel_, address owner_, uint freeze_dur) onlyRenameRole public {
        bytes32 reverseNode = reverseRegistrar.node(owner_);

        require(
            bytes(ensResolver.name(reverseNode)).length > 0,
            "Pass3Registrar: user has not registered"
        );
        
        bytes32 oldLabelNode = keccak256(abi.encodePacked(oldLabel_));
        bytes32 oldNode = keccak256(abi.encodePacked(rootNode, oldLabelNode));

        require(
            ensRegistry.owner(oldNode) == owner_,
            "Pass3Registrar: old name is not owned by owner"
        );
        
        // Update New Forward ENS
        bytes32 newLabelNode = keccak256(abi.encodePacked(newLabel_));
        bytes32 newNode = keccak256(abi.encodePacked(rootNode, newLabelNode));

        require(
            ensRegistry.owner(newNode) == address(0),
            "Pass3Registrar: new name has been registered"
        );

        // Freeze old name
        avaliableTime[oldNode] = block.timestamp + freeze_dur;
        
        // Clear Forward ENS
        ensRegistry.setSubnodeRecord(
            rootNode,
            oldLabelNode,
            address(0),
            address(ensResolver),
            0
        );

        // Assert name has been released in ens registry
        assert(ensRegistry.owner(oldNode) == address(0));

        // Update Forward ENS
        ensRegistry.setSubnodeRecord(
            rootNode,
            newLabelNode,
            owner_,
            address(ensResolver),
            0
        );
        ensResolver.setAddr(newNode, owner_);

        assert(ensRegistry.owner(newNode) == owner_);
        
        // Update Reverse ENS
        ensResolver.setName(reverseNode, newLabel_);

    }

    // ============ ENS Management ============

    /**
     * @notice This function must be called when the ENS Manager contract is replaced
     * and the address of the new Manager should be provided.
     * @param _newOwner The address of the new ENS manager that will manage the root node.
     */
    function changeRootNodeOwner(address _newOwner)
        external
        override
        onlyOwner
    {
        ensRegistry.setOwner(rootNode, _newOwner);
        emit RootNodeOwnerChange(rootNode, _newOwner);
    }

    /**
     * @notice Updates to the reverse registrar.
     */
    function updateENSReverseRegistrar() external override onlyOwner {
        reverseRegistrar = IENSReverseRegistrar(
            ensRegistry.owner(ADDR_REVERSE_NODE)
        );
    }
}
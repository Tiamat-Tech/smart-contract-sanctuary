pragma solidity ^0.8.0;

import "../utils/CloneFactory.sol";
import "./YeetAccess.sol";


contract YeetAccessFactory is CloneFactory {

    /// @notice Responsible for access rights to the contract.
    YeetAccess public accessControls;

    /// @notice Address of the template for access controls.
    address public accessControlTemplate;

    /// @notice Whether initialized or not.
    bool public initialised;

    /// @notice Minimum fee number.
    uint256 public minimumFee;

    /// @notice Devs address.
    address public devaddr;

    /// @notice AccessControls created using the factory.
    address[] public children;

    /// @notice Tracks if a contract is made by the factory.
    mapping(address => bool) public isChild;

    /// @notice Event emitted when first initializing Miso AccessControl Factory.
    event YeetInitAccessFactory(address sender);

    /// @notice Event emitted when a access is created using template id.
    event AccessControlCreated(address indexed owner,  address accessControls, address admin, address accessTemplate);

    /// @notice Event emitted when a access template is added.
    event AccessControlTemplateAdded(address oldAccessControl, address newAccessControl);

    /// @notice Event emitted when a access template is removed.
    event AccessControlTemplateRemoved(address access, uint256 templateId);

    /// @notice Event emitted when a access template is removed.
    event MinimumFeeUpdated(uint oldFee, uint newFee);

    /// @notice Event emitted when a access template is removed.
    event DevAddressUpdated(address oldDev, address newDev);


    constructor() public {
    }

    /**
     * @notice Single gateway to initialize the MISO AccessControl Factory with proper address and set minimum fee.
     * @dev Can only be initialized once.
     * @param _minimumFee Minimum fee number.
     * @param _accessControls Address of the access controls.
     */
    function initYeetAccessFactory(uint256 _minimumFee, address _accessControls) external {
        require(!initialised);
        initialised = true;
        minimumFee = _minimumFee;
        accessControls = YeetAccess(_accessControls);
        emit YeetInitAccessFactory(msg.sender);
    }

    /// @notice Get the total number of children in the factory.
    function numberOfChildren() external view returns (uint256) {
        return children.length;
    }

    /**
     * @notice Creates access corresponding to template id.
     * @dev Initializes access with parameters passed.
     * @param _admin Address of admin access.
     */
    function deployAccessControl(address _admin) external payable returns (address access) {
        require(msg.value >= minimumFee);
        require(accessControlTemplate != address(0), "spam");
        access = createClone(accessControlTemplate);
        isChild[address(access)] = true;
        children.push(address(access));
        YeetAccess(access).initAccessControls(_admin);
        emit AccessControlCreated(msg.sender, address(access), _admin, accessControlTemplate);
        if (msg.value > 0) {
            payable(devaddr).transfer(msg.value);
        }
    }

    /**
     * @notice Function to add new contract templates for the factory.
     * @dev Should have operator access.
     * @param _template Template to create new access controls.
     */
    function updateAccessTemplate(address _template) external {
        // require(
        //     accessControls.hasAdminRole(msg.sender),
        //     addressToString(msg.sender)
        // );
        require(_template != address(0));
        emit AccessControlTemplateAdded(_template, accessControlTemplate);
        accessControlTemplate = _template;
                    // "YeetAccessFactory.updateAccessTemplate: Sender must be admin "

    }

    function addressToString(address _addr) public pure returns(string memory) {
        // bytes32 value = bytes32(uint256(_addr));
        bytes32 value = bytes32(uint256(uint160(_addr)) << 96);

        // address uniqueId = address(bytes20(sha256(abi.encodePacked(msg.sender,'block.timestamp'))));

        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(51);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint(uint8(value[i + 12] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(value[i + 12] & 0x0f))];
        }
        return string(str);
    }

    /**
     * @notice Sets minimum fee.
     * @dev Should have operator access.
     * @param _minimumFee Minimum fee number.
     */
    function setMinimumFee(uint256 _minimumFee) external {
        require(
            accessControls.hasAdminRole(msg.sender),
            "YeetAccessFactory.setMinimumFee: Sender must be admin"
        );
        emit MinimumFeeUpdated(minimumFee, _minimumFee);
        minimumFee = _minimumFee;
    }
}
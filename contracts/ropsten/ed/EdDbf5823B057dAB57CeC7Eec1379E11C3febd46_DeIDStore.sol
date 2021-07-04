// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IdentityStore
 * @version 1.0.0
 * @author Francesco Sullo <[email protected]>
 * @dev Key/value store for identities
 */


// import "hardhat/console.sol";
import "./Application.sol";
import "./interfaces/IDeIDStore.sol";

// the store will be managed by DeIDClaimer and IdentityManager

contract DeIDStore is Application, IDeIDStore {

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint constant public maxNumberOfChains = 100;

    mapping(uint => mapping(uint => address)) private _addressById;
    mapping(uint => mapping(address => uint)) private _idByAddress;
    mapping(uint => uint) public totalIdentities;

    uint public lastTweedentityId;

    // Assigned during the deployment
    uint public chainProgressiveId;

    struct Extra {
        bool isSupported;
        bool isUnique;
        bool isImmutable;
    }

    mapping(bytes32 => Extra) public supportedExtras;
    mapping(uint => mapping(bytes32 => bytes)) public extras;
    mapping(uint => mapping(bytes32 => bytes32)) public uniqueExtras;
    mapping(bytes32 => mapping(bytes32 => bool)) public uniqueExtraExists;


    modifier isSupported(bytes32 key_, bool _isUnique) {
        require(
            supportedExtras[key_].isSupported,
            "Key not supported"
        );
        require(
            supportedExtras[key_].isUnique == _isUnique,
            "Invalid uniqueness"
        );
        _;
    }

    constructor(
        uint chainProgressiveId_
    )
    {
        require(
            chainProgressiveId_ < maxNumberOfChains,
            "chainProgressiveId_ must be < 100"
        );
        chainProgressiveId = chainProgressiveId_;
        addApp(0x7477697474657200000000000000000000000000000000000000000000000000);
        addApp(0x7265646469740000000000000000000000000000000000000000000000000000);
        addApp(0x696e7374616772616d0000000000000000000000000000000000000000000000);
    }

    function setExtraKey(
        bytes32 key_,
        bool unique_,
        bool immutable_
    ) external override
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        require(
            !supportedExtras[key_].isSupported,
            "Key already active"
        );
        supportedExtras[key_] = Extra(true, unique_, immutable_);
    }

    function getExtras(
        address address_,
        bytes32 key_
    ) public view override
    isSupported(key_, false)
    returns (bytes memory value_)
    {
        uint id = _idByAddress[0][address_];
        require(
            id != 0,
            "Account not found"
        );
        return extras[id][key_];
    }


    function setExtras(
        bytes32 key_,
        bytes calldata value_
    ) external override
    isSupported(key_, false)
    {
        uint id = _idByAddress[0][msg.sender];
        require(
            id != 0,
            "Account not found"
        );
        extras[id][key_] = value_;
        emit DataChanged(id, key_, value_);
    }


    function getUniqueExtras(
        address address_,
        bytes32 key_
    ) public view override
    isSupported(key_, true)
    returns (bytes32 value_)
    {
        uint id = _idByAddress[0][address_];
        require(
            id != 0,
            "Account not found"
        );
        return uniqueExtras[id][key_];
    }


    function setUniqueExtras(
        bytes32 key_,
        bytes32 value_
    ) external override
    isSupported(key_, true)
    {
        uint id = _idByAddress[0][msg.sender];
        require(
            id != 0,
            "Account not found"
        );
        if (supportedExtras[key_].isImmutable) {
            require(
                uniqueExtras[id][key_] == 0,
                "Immutable key"
            );
        } else {
            require(
                uniqueExtras[id][key_] != value_,
                "No change required"
            );
            if (uniqueExtras[id][key_] != 0) {
                uniqueExtraExists[key_][uniqueExtras[id][key_]] = false;
            }
        }
        uniqueExtraExists[key_][value_] = true;
        uniqueExtras[id][key_] = value_;
        emit UniqueDataChanged(id, key_, value_);
    }

    // solium-disable-next-line security/no-assign-params
    function setAddressAndIdByAppId(
        uint appId_,
        address address_,
        uint id_
    ) external override
    {
        require(hasRole(MANAGER_ROLE, msg.sender), "Not authorized");
        require(
            apps[appId_] > 0,
            "Unsupported app"
        );
        require(
            address_ != address(0),
            "address_ cannot be 0x0"
        );
        require(
            _idByAddress[appId_][address_] == 0,
            "Existing identity found for appId_/address_"
        );
        if (appId_ == 0) {
            lastTweedentityId++;
            id_ = lastTweedentityId;
        }
        require(
            _addressById[appId_][id_] == address(0),
            "Existing identity found for appId_/id_"
        );

        _idByAddress[appId_][address_] = id_;
        _addressById[appId_][id_] = address_;
        totalIdentities[appId_]++;
        emit IdentitySet(appId_, id_, address_);
    }


    function updateAddressByAppId(
        uint appId_,
        address oldAddress_,
        address newAddress_
    ) external override
    {
        require(hasRole(MANAGER_ROLE, msg.sender), "Not authorized");
        require(
            newAddress_ != address(0),
            "newAddress_ cannot be 0x0"
        );
        require(
            newAddress_ != oldAddress_,
            "No change required"
        );
        require(
            _idByAddress[appId_][oldAddress_] != 0,
            "No identity found for appId_/oldAddress_"
        );
        require(
            _idByAddress[appId_][newAddress_] == 0,
            "Existing identity found for appId_/newAddress_"
        );

        uint id = _idByAddress[appId_][oldAddress_];
        _idByAddress[appId_][newAddress_] = id;
        _addressById[appId_][id] = newAddress_;
        delete _idByAddress[appId_][oldAddress_];
        emit IdentityUpdated(appId_, id, newAddress_);
    }


    function profile(
        address address_
    ) public view override
    returns (uint[] memory)
    {
        uint[] memory ids = new uint[](lastAppId);
        for (uint i = 0; i <= lastAppId; i++) {
            if (_idByAddress[i][address_] != 0) {
                ids[i] = _idByAddress[i][address_];
            }
        }
        return ids;
    }


    function profile() public view override
    returns (uint[] memory)
    {
        return profile(msg.sender);
    }


    function idByAddress(
        uint appId_,
        address address_
    ) public view override
    returns (uint)
    {
        return _idByAddress[appId_][address_];
    }


    function addressById(
        uint appId_,
        uint id_
    ) public view override
    returns (address)
    {
        return _addressById[appId_][id_];
    }

}
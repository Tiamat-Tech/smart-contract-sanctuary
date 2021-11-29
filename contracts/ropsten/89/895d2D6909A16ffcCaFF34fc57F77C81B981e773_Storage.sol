pragma solidity ^0.8.0;

import "./MainProxy.sol";

/**
 * @title A contract for permanent storage accros different implementations.
 * @notice A key-value based storage contract.
 * @dev All setter functions take bytes32 type as a first argument, and desired storage type as a second argument. First argument is a hash of a key for data to be stored, generated using keccak256 hashing algorithm and a second one is a value linked to that key in corresponding storage data type. All getter functions take only one argument in form of bytes32 type, which is a hash of the key, whose value needs to be retrieved, type of retrieved value is corresponding to the type that should be retrieved. All deleters take only one argument of type bytes32, representing the hash of the key for data to be delete.
 */
contract Storage {
    address payable public mainProxy;
    MainProxy MainProxyInstance;

    /**
     * @dev Constructs the Storage contract.
     * @param _mainProxy An address of the EIP1967 Upgradable Proxy for the Main.
     */
    constructor(address payable _mainProxy) {
        mainProxy = _mainProxy;
        MainProxyInstance = MainProxy(_mainProxy);
    }

    // key hash to value mappings by type
    mapping(bytes32 => uint256) uIntStorage;
    mapping(bytes32 => address) addressStorage;
    mapping(bytes32 => bytes32) bytes32Storage;
    mapping(bytes32 => string) stringStorage;
    mapping(bytes32 => bool) boolStorage;

    // allows access to storage only to MainProxy, Main implementation and previous, valid & secure Main implementations
    modifier onlyAllowed() {
		// sender must be either main proxy, current implementation or previous implementation that is a valid, non security risk version
        require(MainProxyInstance.isActiveImplementation(msg.sender) == true || msg.sender == mainProxy,
        "You are not allowed to call this function.");
        _;
    }

    // *** Getter Methods ***
    function getUint(bytes32 _key) external view returns (uint256) {
        return uIntStorage[_key];
    }

    function getAddress(bytes32 _key) external view returns (address) {
        return addressStorage[_key];
    }

    function getBytes32(bytes32 _key) external view returns (bytes32) {
        return bytes32Storage[_key];
    }

    function getString(bytes32 _key) external view returns (string memory) {
        return stringStorage[_key];
    }

    function getBool(bytes32 _key) external view returns (bool) {
        return boolStorage[_key];
    }

    // *** Setter Methods ***
    function setUint(bytes32 _key, uint256 _value) external onlyAllowed {
        uIntStorage[_key] = _value;
    }

    function setAddress(bytes32 _key, address _value) external onlyAllowed {
        addressStorage[_key] = _value;
    }

    function setBytes32(bytes32 _key, bytes32 _value) external onlyAllowed {
        bytes32Storage[_key] = _value;
    }

    function setString(bytes32 _key, string memory _value)
        external
        onlyAllowed
    {
        stringStorage[_key] = _value;
    }

    function setBool(bytes32 _key, bool _value) external onlyAllowed {
        boolStorage[_key] = _value;
    }

    // *** Delete Methods ***
    function deleteUint(bytes32 _key) external onlyAllowed {
        delete uIntStorage[_key];
    }

    function deleteAddress(bytes32 _key) external onlyAllowed {
        delete addressStorage[_key];
    }

    function deleteBytes32(bytes32 _key) external onlyAllowed {
        delete bytes32Storage[_key];
    }

    function deleteString(bytes32 _key) external onlyAllowed {
        delete stringStorage[_key];
    }

    function deleteBool(bytes32 _key) external onlyAllowed {
        delete boolStorage[_key];
    }
}
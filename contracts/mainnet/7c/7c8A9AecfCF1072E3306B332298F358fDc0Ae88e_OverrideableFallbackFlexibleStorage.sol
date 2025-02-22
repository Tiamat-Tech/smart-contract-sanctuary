pragma solidity ^0.5.16;

// Inheritance
import "./synthetix/ContractStorage.sol";
import "./synthetix/interfaces/IFlexibleStorage.sol";

// Internal References
import "./synthetix/interfaces/IAddressResolver.sol";

/// @dev FlexibleStorage that fallsback to an existing FlexibleStorage when no overridden entries exiset
contract OverrideableFallbackFlexibleStorage is ContractStorage, IFlexibleStorage {
    IFlexibleStorage public fallbackStorage;

    mapping(bytes32 => mapping(bytes32 => uint)) internal uintStorage;
    mapping(bytes32 => mapping(bytes32 => int)) internal intStorage;
    mapping(bytes32 => mapping(bytes32 => address)) internal addressStorage;
    mapping(bytes32 => mapping(bytes32 => bool)) internal boolStorage;
    mapping(bytes32 => mapping(bytes32 => bytes32)) internal bytes32Storage;

    constructor(address _resolver, IFlexibleStorage _fallbackStorage) public ContractStorage(_resolver) {
        fallbackStorage = _fallbackStorage;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _setUIntValue(
        bytes32 contractName,
        bytes32 record,
        uint value
    ) internal {
        uintStorage[_memoizeHash(contractName)][record] = value;
        emit ValueSetUInt(contractName, record, value);
    }

    function _setIntValue(
        bytes32 contractName,
        bytes32 record,
        int value
    ) internal {
        intStorage[_memoizeHash(contractName)][record] = value;
        emit ValueSetInt(contractName, record, value);
    }

    function _setAddressValue(
        bytes32 contractName,
        bytes32 record,
        address value
    ) internal {
        addressStorage[_memoizeHash(contractName)][record] = value;
        emit ValueSetAddress(contractName, record, value);
    }

    function _setBoolValue(
        bytes32 contractName,
        bytes32 record,
        bool value
    ) internal {
        boolStorage[_memoizeHash(contractName)][record] = value;
        emit ValueSetBool(contractName, record, value);
    }

    function _setBytes32Value(
        bytes32 contractName,
        bytes32 record,
        bytes32 value
    ) internal {
        bytes32Storage[_memoizeHash(contractName)][record] = value;
        emit ValueSetBytes32(contractName, record, value);
    }

    /* ========== VIEWS ========== */

    function getUIntValue(bytes32 contractName, bytes32 record) public view returns (uint val) {
        val = uintStorage[hashes[contractName]][record];
        if (val == 0) {
            val = fallbackStorage.getUIntValue(contractName, record);
        }
    }

    function getUIntValues(bytes32 contractName, bytes32[] calldata records) external view returns (uint[] memory) {
        uint[] memory results = new uint[](records.length);

        for (uint i = 0; i < records.length; i++) {
            results[i] = getUIntValue(contractName, records[i]);
        }
        return results;
    }

    function getIntValue(bytes32 contractName, bytes32 record) public view returns (int val) {
        val = intStorage[hashes[contractName]][record];
        if (val == 0) {
            val = fallbackStorage.getIntValue(contractName, record);
        }
    }

    function getIntValues(bytes32 contractName, bytes32[] calldata records) external view returns (int[] memory) {
        int[] memory results = new int[](records.length);

        for (uint i = 0; i < records.length; i++) {
            results[i] = getIntValue(contractName, records[i]);
        }
        return results;
    }

    function getAddressValue(bytes32 contractName, bytes32 record) public view returns (address val) {
        val = addressStorage[hashes[contractName]][record];
        if (val == address(0)) {
            val = fallbackStorage.getAddressValue(contractName, record);
        }
    }

    function getAddressValues(bytes32 contractName, bytes32[] calldata records) external view returns (address[] memory) {
        address[] memory results = new address[](records.length);

        for (uint i = 0; i < records.length; i++) {
            results[i] = getAddressValue(contractName, records[i]);
        }
        return results;
    }

    function getBoolValue(bytes32 contractName, bytes32 record) public view returns (bool val) {
        val = boolStorage[hashes[contractName]][record];
        if (val == false) {
            val = fallbackStorage.getBoolValue(contractName, record);
        }
    }

    function getBoolValues(bytes32 contractName, bytes32[] calldata records) external view returns (bool[] memory) {
        bool[] memory results = new bool[](records.length);

        for (uint i = 0; i < records.length; i++) {
            results[i] = getBoolValue(contractName, records[i]);
        }
        return results;
    }

    function getBytes32Value(bytes32 contractName, bytes32 record) public view returns (bytes32 val) {
        val = bytes32Storage[hashes[contractName]][record];
        if (val == bytes32(0)) {
            val = fallbackStorage.getBytes32Value(contractName, record);
        }
    }

    function getBytes32Values(bytes32 contractName, bytes32[] calldata records) external view returns (bytes32[] memory) {
        bytes32[] memory results = new bytes32[](records.length);

        for (uint i = 0; i < records.length; i++) {
            results[i] = getBytes32Value(contractName, records[i]);
        }
        return results;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */
    function setUIntValue(
        bytes32 contractName,
        bytes32 record,
        uint value
    ) external onlyContract(contractName) {
        _setUIntValue(contractName, record, value);
    }

    function setUIntValues(
        bytes32 contractName,
        bytes32[] calldata records,
        uint[] calldata values
    ) external onlyContract(contractName) {
        require(records.length == values.length, "Input lengths must match");

        for (uint i = 0; i < records.length; i++) {
            _setUIntValue(contractName, records[i], values[i]);
        }
    }

    function deleteUIntValue(bytes32 contractName, bytes32 record) external onlyContract(contractName) {
        uint value = uintStorage[hashes[contractName]][record];
        emit ValueDeletedUInt(contractName, record, value);
        delete uintStorage[hashes[contractName]][record];
    }

    function setIntValue(
        bytes32 contractName,
        bytes32 record,
        int value
    ) external onlyContract(contractName) {
        _setIntValue(contractName, record, value);
    }

    function setIntValues(
        bytes32 contractName,
        bytes32[] calldata records,
        int[] calldata values
    ) external onlyContract(contractName) {
        require(records.length == values.length, "Input lengths must match");

        for (uint i = 0; i < records.length; i++) {
            _setIntValue(contractName, records[i], values[i]);
        }
    }

    function deleteIntValue(bytes32 contractName, bytes32 record) external onlyContract(contractName) {
        int value = intStorage[hashes[contractName]][record];
        emit ValueDeletedInt(contractName, record, value);
        delete intStorage[hashes[contractName]][record];
    }

    function setAddressValue(
        bytes32 contractName,
        bytes32 record,
        address value
    ) external onlyContract(contractName) {
        _setAddressValue(contractName, record, value);
    }

    function setAddressValues(
        bytes32 contractName,
        bytes32[] calldata records,
        address[] calldata values
    ) external onlyContract(contractName) {
        require(records.length == values.length, "Input lengths must match");

        for (uint i = 0; i < records.length; i++) {
            _setAddressValue(contractName, records[i], values[i]);
        }
    }

    function deleteAddressValue(bytes32 contractName, bytes32 record) external onlyContract(contractName) {
        address value = addressStorage[hashes[contractName]][record];
        emit ValueDeletedAddress(contractName, record, value);
        delete addressStorage[hashes[contractName]][record];
    }

    function setBoolValue(
        bytes32 contractName,
        bytes32 record,
        bool value
    ) external onlyContract(contractName) {
        _setBoolValue(contractName, record, value);
    }

    function setBoolValues(
        bytes32 contractName,
        bytes32[] calldata records,
        bool[] calldata values
    ) external onlyContract(contractName) {
        require(records.length == values.length, "Input lengths must match");

        for (uint i = 0; i < records.length; i++) {
            _setBoolValue(contractName, records[i], values[i]);
        }
    }

    function deleteBoolValue(bytes32 contractName, bytes32 record) external onlyContract(contractName) {
        bool value = boolStorage[hashes[contractName]][record];
        emit ValueDeletedBool(contractName, record, value);
        delete boolStorage[hashes[contractName]][record];
    }

    function setBytes32Value(
        bytes32 contractName,
        bytes32 record,
        bytes32 value
    ) external onlyContract(contractName) {
        _setBytes32Value(contractName, record, value);
    }

    function setBytes32Values(
        bytes32 contractName,
        bytes32[] calldata records,
        bytes32[] calldata values
    ) external onlyContract(contractName) {
        require(records.length == values.length, "Input lengths must match");

        for (uint i = 0; i < records.length; i++) {
            _setBytes32Value(contractName, records[i], values[i]);
        }
    }

    function deleteBytes32Value(bytes32 contractName, bytes32 record) external onlyContract(contractName) {
        bytes32 value = bytes32Storage[hashes[contractName]][record];
        emit ValueDeletedBytes32(contractName, record, value);
        delete bytes32Storage[hashes[contractName]][record];
    }

    /* ========== EVENTS ========== */

    event ValueSetUInt(bytes32 contractName, bytes32 record, uint value);
    event ValueDeletedUInt(bytes32 contractName, bytes32 record, uint value);

    event ValueSetInt(bytes32 contractName, bytes32 record, int value);
    event ValueDeletedInt(bytes32 contractName, bytes32 record, int value);

    event ValueSetAddress(bytes32 contractName, bytes32 record, address value);
    event ValueDeletedAddress(bytes32 contractName, bytes32 record, address value);

    event ValueSetBool(bytes32 contractName, bytes32 record, bool value);
    event ValueDeletedBool(bytes32 contractName, bytes32 record, bool value);

    event ValueSetBytes32(bytes32 contractName, bytes32 record, bytes32 value);
    event ValueDeletedBytes32(bytes32 contractName, bytes32 record, bytes32 value);
}
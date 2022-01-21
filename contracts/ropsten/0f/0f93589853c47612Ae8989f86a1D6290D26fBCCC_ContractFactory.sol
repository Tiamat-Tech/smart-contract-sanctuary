// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./SystemContext.sol";

/**
 * @dev This contract enables creation of assets smart contract instances
 */
contract ContractFactory {

    mapping (bytes32 => bytes) public contractsBytecode;
    mapping (bytes32 => bool) public hashRegistered;
    SystemContext public systemContext;

    constructor(address systemContext_) {
        systemContext = SystemContext(systemContext_);
    }

    modifier onlyRole(bytes32 role_) {
        systemContext.getAccessControlList().checkRole(role_, msg.sender);
        _;
    }

    /**
    * @dev Registers whitelisted bytecode at its hash.
     * @param bytecode - contract bytecode to whitelist.
     */
    function registerContact(bytes memory bytecode) external onlyRole(systemContext.getAccessControlList().CONTROL_LIST_ADMIN_ROLE()) {
        bytes32 hash = keccak256(bytecode);
        contractsBytecode[hash] = bytecode;
        hashRegistered[hash] = true;
    }

    /**
    * @dev Removes bytecode from whitelist.
     * @param bytecode - contract bytecode in whitelist.
     */
    function deregisterContact(bytes memory bytecode) external onlyRole(systemContext.getAccessControlList().CONTROL_LIST_ADMIN_ROLE()) {
        bytes32 hash = keccak256(bytecode);
        delete contractsBytecode[hash];
        delete hashRegistered[hash];
    }

    /**
    * @dev Removes bytecode from whitelist using it's hash.
     * @param hash - hash of a contract bytecode in whitelist.
     */
    function deregisterContactByHash(bytes32 hash) external onlyRole(systemContext.getAccessControlList().CONTROL_LIST_ADMIN_ROLE()) {
        delete contractsBytecode[hash];
        delete hashRegistered[hash];
    }

    /**
    * @dev Deploys smart contract using given params.
     * @param bytecode - bytecode of a contract to deploy.
     * @param constructorParams - abi packed constructor params.
     * @param salt - data used to ensure that a new contract address is unique.
     */
    function _deploy(bytes memory bytecode, bytes memory constructorParams, bytes32 salt) internal returns(address) {
        bytes memory creationBytecode = abi.encodePacked(bytecode, constructorParams);

        address addr;
        assembly {
            addr := create2(0, add(creationBytecode, 0x20), mload(creationBytecode), salt)
        }

        require(isContract(addr), "Contract was not been deployed. Check contract bytecode and contract params");
        systemContext.getAccessControlList().grantBridgeCallerRole(addr);
        return addr;
    }

    /**
    * @dev Grants caller role to a new whitelisted contract.
    * @param newContract - a contract which will have a bridge caller role.
    */
    function _grantCallerRole(address newContract) internal {
        systemContext.getAccessControlList().grantBridgeCallerRole(newContract);
    }

    /**
     * @dev Creates contract instance for any byteCode.
     * @param bytecode - contract bytecode.
     * @param constructorParams - encoded constructor params.
     * @param salt - data used to ensure that a new contract address is unique.
     */
    function createContractInstance(bytes memory bytecode, bytes memory constructorParams, bytes32 salt) external returns (address) {
        address newContract = _deploy(bytecode, constructorParams, salt);

        // TODO in production env we shouldn't allow that for not whitelisted contracts.
        _grantCallerRole(newContract);
        return newContract;
    }

    /**
    * @dev Creates contract instance for whitelisted byteCode.
     * @param bytecodeHash - hash of a contract bytecode.
     * @param constructorParams - encoded constructor params.
     * @param salt - data used to ensure that a new contract address is unique.
     */
    function createContractInstanceByHash(bytes32 bytecodeHash, bytes memory constructorParams, bytes32 salt) external returns(address) {
        require (hashRegistered[bytecodeHash], "Contract not registered");

        bytes memory bytecode = contractsBytecode[bytecodeHash];
        address newContract = _deploy(bytecode, constructorParams, salt);

        _grantCallerRole(newContract);

        return newContract;
    }

    /**
     * @dev Returns True if provided address is a contract.
     * @param account Prospective contract address.
     * @return True if there is a contract behind the provided address.
     */
    function isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./Whitelist.sol";
import "../SystemContext.sol";

// TODO add support for contract ACLs, limit access to whitelist and creation of new contract instances
/**
 * @dev This contract enables creation of assets smart contract instances
 */
contract ContractFactory is Whitelist, SystemContext {

    event CreatedContractInstance(bytes32 contractName, address contractAddress);

    ContractFactory internal parentFactory;

    constructor(IRegistry contractRegistry, IAuthProvider authProvider, address parentFactory_) SystemContext(contractRegistry, authProvider) {
        parentFactory = ContractFactory(parentFactory_);
    }

    function whitelistContractChecksum(bytes32 checksum) external returns (bool) {
        _addToWhitelist(checksum);
        return true;
    }

    function removeWhitelistedContractChecksum(bytes32 checksum) external returns (bool) {
        _removeFromWhitelist(checksum);
        return true;
    }

    /**
     * @dev Creates contract instance for whitelisted byteCode
     * @param contractName contract name
     * @param bytecode contract bytecode
     * @param constructorParams encoded constructor params
     */
    function createContractInstance(string memory contractName, bytes memory bytecode, bytes memory constructorParams) external returns (bytes32) {
        bytes32 _checksum = keccak256(bytecode);
        require(isChecksumWhitelisted(_checksum), "Contract is not whitelisted. Check contract bytecode");

        bytes32 _contractNameHash = keccak256(abi.encode(contractName));

        bytes memory creationBytecode = abi.encodePacked(bytecode, constructorParams);

        address addr;
        assembly {
            addr := create(0, add(creationBytecode, 0x20), mload(creationBytecode))
        }

        require(isContract(addr), "Contract was not been deployed. Check contract bytecode and contract params");

        IRegistry _registryContract = _getRegistryContract();

        // TODO implement resolver, currently resolver is just an address of deployed contract
        emit CreatedContractInstance(_contractNameHash, addr);
        _registryContract.setRecord(_contractNameHash, msg.sender, addr);

        return _contractNameHash;
    }

    /**
     * @dev Returns True if provided address is a contract
     * @param account Prospective contract address
     * @return True if there is a contract behind the provided address
     */
    function isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Returns true if contract checksum is whitelisted
     * @param checksum The user address
     */
    function isChecksumWhitelisted(bytes32 checksum) public override view returns (bool) {
        if (address(parentFactory) == address(0)) {
            return super.isChecksumWhitelisted(checksum);
        }

        return super.isChecksumWhitelisted(checksum) || parentFactory.isChecksumWhitelisted(checksum);
    }
}
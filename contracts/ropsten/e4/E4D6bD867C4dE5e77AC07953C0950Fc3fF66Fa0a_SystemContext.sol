// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./LayerZeroBridge.sol";
import "./ContractFactory.sol";
import "./CollectionsRegistry.sol";
import "./AccessControlList.sol";

/**
 * @dev This contract stores information about system contract names
 *
 * Provides shared context for all contracts in our network
 */

contract SystemContext {

    LayerZeroBridge internal bridgeContract;
    ContractFactory internal contractFactory;
    CollectionRegistry internal collectionRegistry;
    AccessControlList internal accessControlList;

    constructor (CollectionRegistry collectionRegistry_, AccessControlList accessControlList_) {
        collectionRegistry = collectionRegistry_;
        accessControlList = accessControlList_;
    }

    modifier onlyRole(bytes32 role_) {
        accessControlList.checkRole(role_, msg.sender);
        _;
    }

    function getBridge() external view returns(LayerZeroBridge) {
        return bridgeContract;
    }

    function setBridge(LayerZeroBridge bridgeContract_) external onlyRole(accessControlList.SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE()) {
        bridgeContract = bridgeContract_;
    }

    function getContractFactory() external view returns(ContractFactory) {
        return contractFactory;
    }

    function setContractFactory(ContractFactory contractFactory_) external onlyRole(accessControlList.SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE()) {
        contractFactory = contractFactory_;
    }

    function getCollectionRegistry() external view returns(CollectionRegistry) {
        return collectionRegistry;
    }

    function setCollectionRegistry(CollectionRegistry collectionRegistry_) external onlyRole(accessControlList.SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE()) {
        collectionRegistry = collectionRegistry_;
    }

    function getAccessControlList() external view returns(AccessControlList) {
        return accessControlList;
    }

    function setAccessControlList(AccessControlList accessControlList_) external onlyRole(accessControlList.SYSTEM_CONTEXT_DEFAULT_ADMIN_ROLE()) {
        accessControlList = accessControlList_;
    }
}
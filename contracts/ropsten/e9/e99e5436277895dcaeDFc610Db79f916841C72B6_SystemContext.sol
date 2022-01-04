// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./LayerZeroBridge.sol";
import "./ContractFactory.sol";
import "./CollectionsRegistry.sol";

/**
 * @dev This contract stores information about system contract names
 *
 * Provides shared context for all contracts in our network
 */

contract SystemContext is AccessControl {

    LayerZeroBridge internal bridgeContract;
    ContractFactory internal contractFactory;
    CollectionRegistry internal collectionRegistry;

    constructor (LayerZeroBridge bridgeContract_, ContractFactory contractFactory_, CollectionRegistry collectionRegistry_) {
        bridgeContract = bridgeContract_;
        contractFactory = contractFactory_;
        collectionRegistry = collectionRegistry_;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getBridge() external view returns(LayerZeroBridge) {
        return bridgeContract;
    }

    function setBridge(LayerZeroBridge bridgeContract_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bridgeContract = bridgeContract_;
    }

    function getContractFactory() external view returns(ContractFactory) {
        return contractFactory;
    }

    function setContractFactory(ContractFactory contractFactory_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        contractFactory = contractFactory_;
    }

    function getCollectionRegistry() external view returns(CollectionRegistry) {
        return collectionRegistry;
    }

    function setCollectionRegistry(CollectionRegistry collectionRegistry_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        collectionRegistry = collectionRegistry_;
    }
}
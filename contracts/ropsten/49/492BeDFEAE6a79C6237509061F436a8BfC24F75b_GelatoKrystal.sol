// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {IDiamondCut} from "./standard/IDiamondCut.sol";
import {IDiamondLoupe} from "./standard/IDiamondLoupe.sol";

/// @dev includes the interfaces of all facets
interface IGelatoDiamond {
    // ########## Events: Diamond Cut Facet #########
    event DiamondCut(
        IDiamondCut.FacetCut[] _diamondCut,
        address _init,
        bytes _calldata
    );

    // ########## Events: Ownership Facet #########
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // ########## Events: ExecFacet #########
    event LogExecSuccess(address indexed _service);
    event LogExecFailed(address indexed _service, string indexed revertMsg);

    // ########## Diamond Cut Facet #########
    function diamondCut(
        IDiamondCut.FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    // ########## Ownership Facet #########
    function transferOwnership(address _newOwner) external;

    // ########## AddressFacet #########
    function setOracleAggregator(address _oracleAggregator)
        external
        returns (address);

    function setGasPriceOracle(address _gasPriceOracle)
        external
        returns (address);

    // ########## ExecFacet #########
    function exec(address _service, bytes calldata _data) external;

    function addExecutor(address _executor) external;

    function removeExecutor(address _executor) external;

    // ########## ServiceFacet #########

    function requestService(address _newService) external;

    function acceptService(address _service) external;

    function stopService(address _service) external;

    function blacklistService(address _service) external;

    function deblacklistService(address _service) external;

    // ########## VIEW: DiamondLoupeFacet #########
    function facets()
        external
        view
        returns (IDiamondLoupe.Facet[] memory facets_);

    function facetFunctionSelectors(address _facet)
        external
        view
        returns (bytes4[] memory facetFunctionSelectors_);

    function facetAddresses()
        external
        view
        returns (address[] memory facetAddresses_);

    function facetAddress(bytes4 _functionSelector)
        external
        view
        returns (address facetAddress_);

    function supportsInterface(bytes4 _interfaceId)
        external
        view
        returns (bool);

    // ########## VIEW: OwnershipFacet #########
    function owner() external view returns (address owner_);

    // ########## VIEW: AddressFacet #########
    function getOracleAggregator() external view returns (address);

    function getGasPriceOracle() external view returns (address);

    // ########## VIEW: ExecFacet #########
    function canExecutorExec(address _service, address _executor)
        external
        view
        returns (bool);

    function isExecutor(address _executor) external view returns (bool);

    // ########## VIEW: ServiceFacet #########
    function serviceRequested(address _service) external view returns (bool);

    function serviceAccepted(address _service) external view returns (bool);

    function serviceBlacklisted(address _service) external view returns (bool);
}
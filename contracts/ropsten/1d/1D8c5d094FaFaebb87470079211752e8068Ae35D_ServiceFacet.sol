// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {BFacetOwner} from "../facets/base/BFacetOwner.sol";
import {
    EnumerableSet
} from "../../../vendor/openzeppelin/contracts/utils/EnumerableSet.sol";
import {LibService} from "../libraries/LibService.sol";

contract ServiceFacet is BFacetOwner {
    using EnumerableSet for EnumerableSet.AddressSet;
    using LibService for address;

    function listServices(address[] calldata _services) external onlyOwner {
        for (uint256 i; i < _services.length; i++)
            require(_services[i].listService(), "ServiceFacet.list: already");
    }

    function unlistServices(address[] calldata _services) external onlyOwner {
        for (uint256 i; i < _services.length; i++)
            require(
                _services[i].unlistService(),
                "ServiceFacet.unlist: already"
            );
    }

    function isListedService(address _service) external view returns (bool) {
        return _service.isListedService();
    }

    function listedServices() external view returns (address[] memory) {
        return LibService.listedServices();
    }
}
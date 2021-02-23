// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {BFacetOwner} from "../facets/base/BFacetOwner.sol";
import {BFacetExecutors} from "../facets/base/BFacetExecutors.sol";
import {
    EnumerableSet
} from "../../../vendor/openzeppelin/contracts/utils/EnumerableSet.sol";
import {GelatoBytes} from "../../../lib/GelatoBytes.sol";
import {LibDiamond} from "../libraries/standard/LibDiamond.sol";
import {LibExecutor} from "../libraries/LibExecutor.sol";
import {LibService} from "../libraries/LibService.sol";

contract ExecFacet is BFacetOwner, BFacetExecutors {
    using EnumerableSet for EnumerableSet.AddressSet;
    using GelatoBytes for bytes;
    using LibDiamond for address;
    using LibExecutor for address;
    using LibService for address;

    event LogExecSuccess(address indexed _service);
    event LogExecFailed(address indexed _service, string revertMsg);

    // ################ Callable by Gov ################
    function addExecutors(address[] calldata _executors) external onlyOwner {
        for (uint256 i; i < _executors.length; i++)
            require(_executors[i].addExecutor(), "ExecFacet.addExecutors");
    }

    function removeExecutors(address[] calldata _executors) external {
        for (uint256 i; i < _executors.length; i++) {
            require(
                msg.sender == _executors[i] || msg.sender.isContractOwner(),
                "ExecFacet.removeExecutors: msg.sender ! executor || owner"
            );
            require(
                _executors[i].removeExecutor(),
                "ExecFacet.removeExecutors"
            );
        }
    }

    // ################ Callable by Executor ################
    /// @dev we don't check
    function exec(address _service, bytes calldata _data)
        external
        onlyExecutors
    {
        require(
            _service.isListedService(),
            "ExecFacet.exec: !_service.isListed"
        );

        (bool success, bytes memory returndata) = _service.call(_data);

        if (success) emit LogExecSuccess(_service);
        else
            emit LogExecFailed(
                _service,
                returndata.returnError("ExecFacet.exec:")
            );
    }

    // ################ View fns ################
    function canExec(address _service, address _executor)
        external
        view
        returns (bool)
    {
        return _service.canExec(_executor);
    }

    function isExecutor(address _executor) external view returns (bool) {
        return _executor.isExecutor();
    }

    function executors() external view returns (address[] memory) {
        return LibExecutor.executors();
    }
}
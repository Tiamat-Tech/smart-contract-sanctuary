// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";

import {Operator} from "./utils/Operator.sol";

interface OperationStandard {
    function initialize(bytes memory) external;

    function initPayload(address, bytes32) external view returns (bytes memory);
}

interface IFactory {
    event ContractDeployed(
        address indexed deployer,
        address indexed instance,
        bytes32 indexed terraAddress
    );

    function build(uint256 _optId, address _controller)
        external
        returns (address);
}

contract Factory is IFactory, Operator {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // permission
    mapping(address => bool) public permission;

    function allow(address _target) public onlyOwner {
        permission[_target] = true;
    }

    function deny(address _target) public onlyOwner {
        permission[_target] = false;
    }

    function isPermissioned(address _target) public view returns (bool) {
        return permission[_target];
    }

    // standard operations
    mapping(uint256 => address) internal standards;

    function setStandardOperation(uint256 _optId, address _operation)
        public
        onlyOwner
    {
        standards[_optId] = _operation;
    }

    // terra address buffer
    EnumerableSet.Bytes32Set private terraAddresses;

    function pushTerraAddresses(bytes32[] memory _addrs) public onlyOwner {
        for (uint256 i = 0; i < _addrs.length; i++) {
            terraAddresses.add(_addrs[i]);
        }
    }

    function fetchNextTerraAddress() public view returns (bytes32) {
        return terraAddresses.at(0);
    }

    function fetchTerraAddress() private returns (bytes32) {
        bytes32 addr = terraAddresses.at(0);
        terraAddresses.remove(addr);
        return addr;
    }

    function build(uint256 _optId, address _controller)
        public
        override
        onlyGranted
        returns (address)
    {
        require(isPermissioned(msg.sender), "Factory: not allowed");

        bytes32 terraAddr = fetchTerraAddress();
        address instance = Clones.clone(standards[_optId]);
        bytes memory payload =
            OperationStandard(standards[_optId]).initPayload(
                _controller,
                terraAddr
            ); // TODO: make terraAddress buffer
        OperationStandard(instance).initialize(payload);

        emit ContractDeployed(msg.sender, instance, terraAddr);

        return instance;
    }
}
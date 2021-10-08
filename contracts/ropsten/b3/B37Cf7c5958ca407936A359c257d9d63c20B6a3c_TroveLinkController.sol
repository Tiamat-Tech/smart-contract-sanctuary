// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./interfaces/ITroveLinkAccessController.sol";
import "./interfaces/ITroveLinkController.sol";
import "./AddressUtils.sol";

contract TroveLinkController is ITroveLinkController {
    using AddressUtils for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _services;
    address private _voting;

    function voting() public view returns (address) {
        return _voting;
    }

    function serviceCount() external view override(ITroveLinkController) returns (uint256) {
        return _services.length();
    }

    function isService(address service_) external view override(ITroveLinkController) returns (bool) {
        return _services.contains(service_);
    }

    function service(uint256 index_) external view override(ITroveLinkController) returns (address) {
        return _services.at(index_);
    }

    constructor(address voting_, address[] memory services_) public {
        _updateVoting(voting_);
        for (uint256 i = 0; i < services_.length; i++) {
            _addService(services_[i]);
        }
    }

    function addService(address service_) external override(ITroveLinkController) returns (bool) {
        require(msg.sender == address(this), "Invalid sender");
        require(!_services.contains(service_), "Service already added");
        _addService(service_);
        return true;
    }

    function execute(
        address destination_,
        bytes memory data_,
        string memory description_
    ) external payable override(ITroveLinkController) returns (bytes memory result) {
        require(msg.sender == _voting, "Invalid sender");
        uint256 value = msg.value;
        result = destination_.functionCallWithValue(
            data_,
            value,
            "Execution error"
        );
        emit Executed(
            destination_,
            data_,
            description_,
            value
        );
    }

    function removeService(address service_) external override(ITroveLinkController) returns (bool) {
        require(msg.sender == address(this), "Invalid sender");
        require(_services.contains(service_), "Service is not added");
        _services.remove(service_);
        emit ServiceRemoved(service_);
        return true;
    }

    function updateVoting(address voting_) external override(ITroveLinkController) returns (bool) {
        require(msg.sender == address(this), "Invalid sender");
        _updateVoting(voting_);
        return true;
    }

    function _addService(address service_) private {
        require(service_ != address(0), "Service is zero address");
        if (_services.add(service_)) emit ServiceAdded(service_);
    }

    function _updateVoting(address voting_) private {
        require(voting_ != address(0), "Voting is zero address");
        _voting = voting_;
        emit VotingUpdated(voting_);
    }
}
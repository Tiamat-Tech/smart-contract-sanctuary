// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./Redeemer.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RedeemerFactory is AccessControl, Pausable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct FedMemberRedeemers {
        bool added;
        address[] redeemers;
    }

    mapping(address => FedMemberRedeemers) fedMembersRedeemers;
    address fluentUSDPlusAddress;

    constructor(address _fluentUSDPlusAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _fluentUSDPlusAddress);
        
        fluentUSDPlusAddress = _fluentUSDPlusAddress;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function addNewFedMember(address fedMemberId)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        returns (address)
    {
        require(
            !fedMembersRedeemers[fedMemberId].added,
            "FEDMEMBER ALREADY ADDED"
        );

        Reedemer newRedeemer = new Reedemer(fluentUSDPlusAddress, fedMemberId);

        fedMembersRedeemers[fedMemberId].added = true;
        fedMembersRedeemers[fedMemberId].redeemers.push(address(newRedeemer));

        return address(newRedeemer);
    }

    function getRedeemers(address fedMemberId)
        public
        view
        returns (address[] memory)
    {
        return fedMembersRedeemers[fedMemberId].redeemers;
    }

    function addNewRedeemer(address fedMemberId)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        returns (address)
    {
        require(fedMembersRedeemers[fedMemberId].added, "FEDMEMBER NOT ADDED");

        Reedemer newRedeemer = new Reedemer(fluentUSDPlusAddress, fedMemberId);
        fedMembersRedeemers[fedMemberId].redeemers.push(address(newRedeemer));

        return address(newRedeemer);
    }
}
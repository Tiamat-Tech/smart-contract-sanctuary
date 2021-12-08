// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AgreementContract is Ownable {

    using Counters for Counters.Counter;                                                                                                                                               
    Counters.Counter public contractIds;

    struct Contract {
        string contractName;
        string userId;
        string privacy;
        string agencyTeam;
        string description;
        uint256 startDate;
        uint256 stopDate;
        uint256 amount;
        string contractDocument;
        // Milestone[]  miles;
        // mapping(uint256 => Milestones) milestones;
    }

    struct Milestone {
        string milestone;
        string dueDate;
        string priority;
        uint256 _amount;
    }

    mapping(uint256 => mapping(string => bool)) public _approveContract;
    mapping(uint256 => Contract) public contractInfo;
    mapping(uint256 => mapping (uint256 => Milestone)) public milestonesInfo;          // contratId => milestoneId => milestoneInfo
  
  
    function addContract(
        Contract calldata _contract
    ) external onlyOwner returns (uint256) {

        contractIds.increment();
        uint256 newItemId = contractIds.current();
        contractInfo[newItemId] = _contract;
        return newItemId;
    }

    function addMilestone(
        uint256 contractId,
        uint256 milestoneId,
        Milestone[] calldata _milestone
    ) external onlyOwner {
        for (uint256 index = 0; index < _milestone.length; index++) {
            milestonesInfo[contractId][milestoneId] = _milestone[index];        
        }
    }

    function approveContract(uint256 contractId, string memory employeeId , bool status)external {
    require(!_approveContract[contractId][employeeId],"user already approved");
    _approveContract[contractId][employeeId] = status;
    }
    
}
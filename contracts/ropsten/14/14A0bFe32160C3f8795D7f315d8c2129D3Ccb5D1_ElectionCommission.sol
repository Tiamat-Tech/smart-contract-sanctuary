// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "./Candidate.sol";
import "./Voter.sol";

contract ElectionCommission {
    address ec_admin;
    Candidate candidateContract;
    Voter voterContract;

    constructor() {
        ec_admin = msg.sender;
        candidateContract = new Candidate(address(this));
        voterContract = new Voter(address(candidateContract));
    }

    modifier is_ECAdmin() {
        require(
            msg.sender == ec_admin,
            " You are not an administrator of this contract"
        );
        _;
    }

    function getCandidateContractAddress()
        public
        view
        returns (address candidateContractAddress)
    {
        return address(candidateContract);
    }

    function getVoterContractAddress()
        public
        view
        returns (address voterContractAddress)
    {
        return address(voterContract);
    }
}
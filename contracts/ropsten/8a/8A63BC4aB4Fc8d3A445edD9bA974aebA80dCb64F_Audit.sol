//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Audit {
    struct Voter {
        uint256[] preferences;
        uint256 current;
    }

    address[] votersArray;

    mapping(address => Voter) public allVoters;

    event VotePref(address id, uint256[] preferences);
    event Voted(address id, uint256 vote);

    constructor() {
        console.log('Audit contract created');
    }

    function vote(uint256[] memory _preferences) public {
        // todo checks to verify the user is allowed to vote
        // todo checks to verify perferences is in the correct format

        Voter memory voterStruct = Voter(_preferences, 0);

        allVoters[msg.sender] = voterStruct;

        votersArray.push(msg.sender);

        // log the vote preferences
        emit VotePref(msg.sender, _preferences);

        // log a vote
        emit Voted(msg.sender, _preferences[0]);
    }

    function audit() public {
        for (uint i = 0; i < votersArray.length; i++) {
            Voter memory voterStruct = allVoters[votersArray[i]];

            // log the vote preferences
            emit VotePref(votersArray[i], voterStruct.preferences);

            // log a vote
            emit Voted(votersArray[i], voterStruct.preferences[voterStruct.current]);
        }
    }
}
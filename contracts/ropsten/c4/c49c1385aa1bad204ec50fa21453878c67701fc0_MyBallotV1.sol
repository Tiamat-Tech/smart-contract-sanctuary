// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract MyBallotV1 is ERC721Upgradeable {
    // This will declare a new complex data type, which we can use to represent individual voters.
    struct ballotVoter {
        uint256 delegateWeight; // delegateWeight is accumulated by delegation
        bool voteSpent; // if true, that person already used their vote
        address delegateTo; // the person that the voter chooses to delegate their vote to instead of voting themselves
        uint256 voteIndex; // index of the proposal that was voted for
    }

    // This is a type for a single proposal.
    struct Proposal {
        bytes32 proposalName; // short name for the proposal (up to 32 bytes)
        uint256 voteCount; // the number of votes accumulated
    }

    address public chairman;

    // Declare state variable to store a 'ballotVoter' struct for every possible address.
    mapping(address => ballotVoter) public ballotVoters;

    // A dynamically-sized array of 'Proposal' structs.
    Proposal[] public proposalsOption;

    function initialize(uint256 _numProposalNames) public initializer {
        __ERC721_init("MyBallotV1", "MBTV1");
        chairman = msg.sender;
        ballotVoters[chairman].delegateWeight = 1;

        // For every provided proposal names, a new proposal object is created and added to the array's end.
        for (uint256 i = 0; i < _numProposalNames; i++) {
            proposalsOption.push(
                Proposal({proposalName: randomName(i), voteCount: 0})
            );
        }
    }

    function randomName(uint256 seed) internal view returns (bytes32) {
        return
            bytes32(
                keccak256(
                    abi.encodePacked(
                        tx.origin,
                        blockhash(block.number - 1),
                        block.timestamp,
                        seed
                    )
                )
            );
    }

    // Give 'ballotVoter' the right to cast a vote on this ballot.
    // Can only be called by 'chairman'.
    function giveVotingRights(address _ballotVoter) public {
        require(
            (msg.sender == chairman) &&
                !ballotVoters[_ballotVoter].voteSpent &&
                (ballotVoters[_ballotVoter].delegateWeight == 0)
        );
        ballotVoters[_ballotVoter].delegateWeight = 1;
    }

    /// Delegate your vote to the voter 'to'.
    function delegateTo(address to) public {
        // assigns reference
        ballotVoter storage sender = ballotVoters[msg.sender];
        require(!sender.voteSpent);

        // Self-delegation is not allowed.
        require(to != msg.sender);

        while (ballotVoters[to].delegateTo != address(0)) {
            to = ballotVoters[to].delegateTo;

            // We found a loop in the delegation, not allowed.
            require(to != msg.sender);
        }

        // Since 'sender' is a reference, this will modify 'ballotVoters[msg.sender].voteSpent'
        sender.voteSpent = true;
        sender.delegateTo = to;
        ballotVoter storage _delegateTo = ballotVoters[to];
        if (_delegateTo.voteSpent) {
            // If the delegated person already voted, directly add to the number of votes
            proposalsOption[_delegateTo.voteIndex].voteCount += sender
                .delegateWeight;
        } else {
            // If the delegated did not vote yet,
            // add to her delegateWeight.
            _delegateTo.delegateWeight += sender.delegateWeight;
        }
    }

    /// Give your vote (including votes delegated to you) to proposal 'proposalsOption[proposal].proposalName'.
    function voteIndex(uint256 proposal) public {
        ballotVoter storage sender = ballotVoters[msg.sender];
        require(!sender.voteSpent);
        sender.voteSpent = true;
        sender.voteIndex = proposal;

        // If 'proposal' is out of the range of the array,
        // this will throw automatically and revert all
        // changes.
        proposalsOption[proposal].voteCount += sender.delegateWeight;
    }

    /// @dev Computes which proposal wins by taking all previous votes into account.
    function winnerProposal() public view returns (uint256 _winnerProposal) {
        uint256 winnerVoteCount = 0;
        for (uint256 p = 0; p < proposalsOption.length; p++) {
            if (proposalsOption[p].voteCount > winnerVoteCount) {
                winnerVoteCount = proposalsOption[p].voteCount;
                _winnerProposal = p;
            }
        }
    }

    /// Calls winnerProposal() function in order to acquire the index
    /// of the winner which the proposalsOption array contains and then
    /// returns the name of the winning proposal
    function winner() public view returns (bytes32 _winner) {
        _winner = proposalsOption[winnerProposal()].proposalName;
    }
}
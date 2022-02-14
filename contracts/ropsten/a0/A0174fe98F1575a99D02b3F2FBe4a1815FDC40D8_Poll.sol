/**
 *Submitted for verification at Etherscan.io on 2022-02-14
*/

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Poll {
    //VARIABLES
    struct response {
        string name;
        uint nbVote;
    }

    struct inrep {
        string x;
        string z;
    }

    string public question;
    mapping(string => response) responses;
    uint public voteCount;

    enum State { Voting, Ended }
    State public state;

    address public owner;

    // MODIFIERS
    modifier condition(bool _condition) {
        require(_condition);
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    //FUNCTION
    constructor(string memory _question, string[] memory _responseNames) {
        owner = msg.sender;

        question = _question;
        for (uint i = 0; i < _responseNames.length; i++) {
            responses[_responseNames[i]] = response({
                name: _responseNames[i],
                nbVote: 0
            });
        }
        voteCount = 0;

        state = State.Voting;
    }

    function vote(string[] memory _responses, uint[] memory votes) 
        public
        onlyOwner()
        inState(State.Voting)
    {
        for (uint8 i = 0; i < _responses.length; i++) {
            responses[_responses[i]].nbVote = votes[i];
        }
    }

    function testDecode(inrep memory r) public onlyOwner() {
        voteCount = voteCount + 1;
        voteCount = voteCount - 1;
    }

    function endVote()
        public
        inState(State.Voting)
        onlyOwner()
    {
        state = State.Ended;
    }
}
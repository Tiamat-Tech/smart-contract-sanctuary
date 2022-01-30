// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

import "./voting.sol";
 
contract Voter
{
    mapping (uint => Voting) votings;
    uint id;

    constructor()
    {
        id = 0;
    }

    function start_voting(string memory _title, string[] memory _variants, uint _duration) public returns(uint _id)
    {
        require(bytes(_title).length > 0, "Invalid title");
        require(_variants.length > 0, "Invalid variants");

        for (uint i = 0; i < _variants.length; ++i)
            require(bytes(_variants[i]).length > 0, "Invalid variant");

        require(_duration > 0, "Invalid duration");

        ++id;
        votings[id] = new Voting(id, msg.sender, _title, _variants, _duration);

        return id;
    }

    function vote(uint _id, uint _variant) public
    {
        require(_id > 0 && _id <= id, "Invalid voting id");

        votings[_id].vote(msg.sender, _variant);
    }

    function vote(uint _id, string calldata _variant) public
    {
        require(_id > 0 && _id <= id, "Invalid voting id");

        votings[_id].vote(msg.sender, _variant);
    }

    function get_results(uint _id) public returns(uint[] memory _results, bool finished)
    {
        require(_id > 0 && _id <= id, "Invalid voting id");

        return votings[_id].get_results();
    }
}
// SPDX-License-Identifier: GPL-3.0
 
pragma solidity >=0.8.7;

import "./variant.sol";
import "./voting.sol";

contract Main {
    mapping(address => mapping(address => bool)) voted;
    address[] votings;
    
    address immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function createVoting(string memory name, string memory description, bool anonymousVoting) public returns(address){
        Voting voting = new Voting(name, description, msg.sender, anonymousVoting);
        votings.push(address(voting));
        return address(voting);
    }

    function addVariantToVoting(address voting, string memory name, string memory description) public{
            VotingInterface(voting).addVariant(msg.sender,  name, description);
    }

    function getVotings() public view returns(address[] memory, string[] memory){
        string[] memory answer = new string[](votings.length);
        for (uint i = 0; i < votings.length; i++){
            answer[i] = VotingInterface(votings[i]).getName();
        }
        return (votings, answer);
    }

    function getVotingVariants(address voting) public view returns(string[] memory){
        VotingInterface.variant[] memory vars = VotingInterface(voting).getVariants();
        string[] memory ans = new string[](vars.length);
        for (uint i = 0; i < vars.length; i++){
            ans[i] = vars[i].name;
        }
        return ans;
    }

    function vote(address voting, uint[] memory variants) public{
        require(!voted[voting][msg.sender], "You've already voted!");
        voted[voting][msg.sender] = true;
        VotingInterface currentVoting = VotingInterface(voting);
        VotingInterface.variant[] memory possibleVariants = currentVoting.getVariants();
        //console.log(currentVoting.getSingle());
        require((currentVoting.getSingle() && variants.length == 1) || !currentVoting.getSingle(), "Only 1 variant is possible!");
        for (uint i = 0; i < variants.length; i++){
            require(variants[i] < possibleVariants.length, "Impossible answer");
            //console.log("aaaa");
            //console.log(variants[i]);
            //console.log("cccc");
            //console.log(VariantInterface(possibleVariants[variants[i]].addr).);
            VariantInterface(possibleVariants[variants[i]].addr).addUser(msg.sender);
            //console.log("bbbb");
        }
    }

    struct votingRes{
        string name;
        uint count;
        address[] users;
    }

    function getVotingResults(address voting) public view returns(votingRes[] memory){
        VotingInterface votingInt = VotingInterface(voting);
        VotingInterface.variant[] memory variants = votingInt.getVariants();
        votingRes[] memory res = new votingRes[](variants.length);
        for (uint i = 0; i < res.length; i++){
            VariantInterface varInt = VariantInterface(variants[i].addr);
            res[i] = votingRes(varInt.getName(), varInt.getUsersCount(), varInt.getUsers()); 
        }
        return res;
    }

    function startVoting(address voting, uint _days, bool _isSingle, bool _isEndless) public {
        //console.log(_isSingle);
        VotingInterface(voting).startVoting(msg.sender, _days, _isSingle, _isEndless);
    }
}
/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;


contract Election {

    struct Candidate{
        uint id;
        string name;
        string description;
        uint8 age;
        uint voters;
    }

    string title;
    address ownerAddress;
    Candidate[] candidates;
    address[] allVoters;
    bool start = false;
    bool end = false;


    //event vote(voterAddress, candidateId);
    event vote(address, uint);

    constructor(string memory _title){
        title = _title;
        ownerAddress = msg.sender;
    }

    /// Vote for a candidate by name
    /// @param _name the name of the candidate
    function voteForCandidate(string memory _name) external{
        require(!didVote(msg.sender));
        require(start);
        uint cId = getIdByName(_name);
        require(cId < candidates.length);
        candidates[cId].voters += 1;

        allVoters.push(msg.sender);
        emit vote(msg.sender, cId);
    }

    /// Vote for a candidate by his id    
    /// @param candidateId the id of the candidate
    function voteForCandidate(uint candidateId) external {
        require(!didVote(msg.sender));
        require(start);
        require(0 <= candidateId && candidateId < candidates.length);
        candidates[candidateId].voters += 1;

        allVoters.push(msg.sender);
        emit vote(msg.sender, candidateId);
    }

    /// Function to add a new candidate. Can be called only by contract owner 
    /// @param _name the name of the candidate
    /// @param _description the description of the candidate
    /// @param _age the age of the candidate
    function addCandidate(string memory _name, string memory _description, uint8 _age) external {
        require(msg.sender == ownerAddress);
        candidates.push(Candidate(candidates.length, _name, _description, _age, 0));
    }
    

    /// Function to start election
    function startVoting() external {
        require(msg.sender == ownerAddress);
        start = true;
        end = false;
    }

    /// Function to end election
    function endVoting() external {
        require(msg.sender == ownerAddress);
        start = false;
        end = true;
    }

    /// Function to get candidates count 
    function getCandidatesCount() external view returns(uint){
        return candidates.length;
    }

    /// Function to get voters count 
    function getVotersCount() external view returns(uint){
        return allVoters.length;
    }

    /// Function to get information about candidate by his name  
    /// @param _name the name of the candidate
    function getCandidate(string memory _name) external view returns(Candidate memory){
        uint cId = getIdByName(_name);
        require(cId < candidates.length);
        return candidates[cId];
    }

    /// Function to get information about candidate by his id  
    /// @param cId the id of the candidate
    function getCandidate(uint cId) external view returns(Candidate memory){
        require(0 <= cId && cId < candidates.length);
        return candidates[cId];
    }

    /// Get candidate id by his name  
    /// @param _name the name of the candidate
    function getIdByName(string memory _name) private view returns(uint){
        for(uint i = 0; i < candidates.length; i++){
            if (keccak256(abi.encodePacked(candidates[i].name)) == keccak256(abi.encodePacked(_name))){
                return i;
            }
        }
        return candidates.length;
    }

    /// Function to check if voter has already voted
    /// @param voter address of the owner
    function didVote(address voter) private view returns(bool){
        for(uint i = 0; i < allVoters.length; i++){
            if(allVoters[i] == voter)
                return true;
        }
        return false;
    }

}
/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Voting{
    
    struct Candidate{
        
        string name;
        uint128 VoteCount;
    }
    
    Candidate[] Candidates;
   // mapping(uint=>Candidate)Candidates;
    mapping(address=>bool)Participants;

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
   }
    
    uint128 CandidateCount;
    address owner;
    
    constructor(){
        owner=msg.sender;
    }
    
    function AddCandidate(string memory _name) public onlyOwner returns(string memory){
             
       Candidates.push(Candidate({name:_name,VoteCount:0}));
       return "Success";
    }
    
    function Vote(uint id) public returns(string memory){
        require(id<Candidates.length && id>=0 ,"Candidate Not Found");
        require(Participants[msg.sender]==false,"You have already voted");
        Candidates[id].VoteCount++;
        Participants[msg.sender]=true;
        return "Success";
    }
    function VoteCondidate(uint id)view public returns(Candidate memory){
        Candidate memory selectionCandidate=Candidates[id];
        return selectionCandidate;
        
    }

    
    function ShowWinner() view public returns(string memory){
            uint winnerID=0;
            uint winnerVote=0;
            
            for(uint i=0;i<Candidates.length;i++){
                if(Candidates[i].VoteCount>=winnerVote){
                    winnerID=i;
                    winnerVote=Candidates[i].VoteCount;
                }
            }
            return Candidates[winnerID].name;            
    }
    
}
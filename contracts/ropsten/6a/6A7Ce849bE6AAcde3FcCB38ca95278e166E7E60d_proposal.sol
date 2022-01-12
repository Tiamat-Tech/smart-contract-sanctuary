// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract proposal is Ownable{

    struct Proposal {
        uint256 proposalID;
        address contractor;
        uint256 contractorProposalID;
        uint256 amount;
        address moderator;
        uint256 amountForShares;
        uint256 initialSharePriceMultiplier; 
        uint256 amountForTokens;
        uint256 minutesFundingPeriod;
        uint256 proposalStart;
        uint256 proposalEnd;
        bool open; 
    }

    struct Rules {
        // Index to identify a committee
        uint256 committeeID; 
        // The quorum needed for each proposal is calculated by totalSupply / minQuorumDivisor
        uint256 minQuorumDivisor;  
        // Minimum fees (in wei) to create a proposal
        uint256 minCommitteeFees; 
        // Minimum percentage of votes for a proposal to reward the creator
        uint256 minPercentageOfLikes;
        // Period in minutes to consider or set a proposal before the voting procedure
        uint256 minutesSetProposalPeriod; 
        // The minimum debate period in minutes that a generic proposal can have
        uint256 minMinutesDebatePeriod;
        // The inflation rate to calculate the reward of fees to voters
        uint256 feesRewardInflationRate;
        // The inflation rate to calculate the token price (for project manager proposals) 
        uint256 tokenPriceInflationRate;
        // The default minutes funding period
        uint256 defaultMinutesFundingPeriod;
    } 

    struct proposalDecision{
        uint256 upvote;
        uint256 downvote;
        uint256 __proposalId;

    }

    mapping(uint256 => Proposal) public proposaldetail;
    mapping(uint256 => Rules) public rulesInfo;
    mapping(uint256 => proposalDecision) public proposalfinal;


constructor()  {

    }

    function createRule(uint256 ruleNo , Rules calldata _ruleInfo)external  onlyOwner {
        require(rulesInfo[ruleNo].committeeID == 0,"rule of that rule no is already craeted");

         rulesInfo[ruleNo]=_ruleInfo;
    }

    function updateRule(uint256 ruleNo , Rules calldata _ruleInfo)external onlyOwner{
        require(rulesInfo[ruleNo].committeeID == 0,"first create the rule");
        
        rulesInfo[ruleNo]=_ruleInfo;
    }

    function createProposal(uint256 _proposalId , Proposal calldata _proposalDeposite)external onlyOwner {
        require(proposaldetail[_proposalId].proposalStart == 0,"proposal of that proposalId already craeted");
    
        proposaldetail[_proposalId]=_proposalDeposite;
    }

    function updateProposal(uint256 _proposalId , Proposal calldata _proposalDeposite)external onlyOwner{
        require(proposaldetail[_proposalId].proposalStart == 0,"first create the proposal");
        require(proposaldetail[_proposalId].proposalStart >= block.timestamp,"proposal canot be update when proposal voting time start");
        
        proposaldetail[_proposalId]=_proposalDeposite;
    }

    function vote(uint256 _proposalId, bool _vote ) external {
        require(proposaldetail[_proposalId].proposalStart <= block.timestamp ,"proposal voting time not yet started");
        require(block.timestamp <= proposaldetail[_proposalId].proposalEnd ,"proposal voting time ended");
    
    
        proposalfinal[_proposalId].__proposalId = _proposalId;
        uint256 count1 =  proposalfinal[_proposalId].upvote;
        uint256 count2 =  proposalfinal[_proposalId].downvote;
    
            if(_vote == true){
                count1 ++;
            }else{
                count2 ++ ; 
            }
           
    
    }


    function proposalFinalDecision(uint256 _proposalId) public view virtual returns(bool){
        require(proposaldetail[_proposalId].proposalStart < block.timestamp ,"proposal voting time not yet started");
        
        require(block.timestamp > proposaldetail[_proposalId].proposalEnd ,"proposal voting time not yet ended");

        if(proposalfinal[_proposalId].upvote > proposalfinal[_proposalId].downvote){
            return true;
        } else{
        return false;
        }
    }



}
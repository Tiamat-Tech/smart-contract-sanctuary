/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract Oracle {
    
  
    struct Offer {
        string title;
        string description;
        uint256 reward;
        uint256 numberOfOracles;
        uint256 oracleLockValue;
        uint256 deadline;
        uint256 id;
    }

    struct answerType{
        address[] senders;
        uint256 answersCount;
        string fileHash;
        string fileUrl;
    }

    struct MoreInfo {
        address owner;
        uint256 answersTypeCount;
        mapping (uint256 => answerType) answers;
    }

    mapping(uint256 => Offer) private offers;
    mapping(uint256 => MoreInfo) private moreinfo;

    uint256 private offersCount;
    uint256 private activeOffersCount;

    event NewOffer(Offer);

    function createOffer(
        string calldata title,
        string calldata description,
        uint256 numberOfOracles,
        uint256 oracleLockValue,
        uint256 activeDays
    ) public payable returns (uint256) {
        require(msg.value > 0, "Reward must be greater than 0");

        Offer storage o = offers[++offersCount];
        o.title = title;
        o.description = description;
        o.reward = msg.value;
        o.numberOfOracles = numberOfOracles;
        o.oracleLockValue = oracleLockValue;
        o.deadline = block.timestamp + (activeDays * 24 * 60 * 60);
        o.id = offersCount;

        MoreInfo storage i = moreinfo[offersCount];
        i.owner = msg.sender;

        activeOffersCount++;

        emit NewOffer(o);

        return offersCount;
    }

    function getOffer(uint256 offerNumber) public view returns (Offer memory) {
        return offers[offerNumber];
    }

    function getActiveOffers() public view returns (Offer[] memory) {
        Offer[] memory activeOffers = new Offer[](activeOffersCount);

        uint256 j = 0;

        for (uint256 i = 0; i <= offersCount; i++) {
            if (block.timestamp < offers[i].deadline) {
                activeOffers[j] = offers[i];
                j++;
            }
        }

        return activeOffers;
    }
    function submitAnswer(uint256 offerNumber, string memory fileHash, string memory url) public payable{
        require(msg.value == offers[offerNumber].oracleLockValue, "Wrong lock value.");
        if(moreinfo[offerNumber].answersTypeCount == 0){
            moreinfo[offerNumber].answersTypeCount++;
            answerType storage answer = moreinfo[offerNumber].answers[moreinfo[offerNumber].answersTypeCount];
            answer.senders.push(msg.sender);
            answer.answersCount=1;
            answer.fileHash=fileHash;
            answer.fileUrl=url;
        }else{
            bool found=false;
            for (uint256 i = 0; i <=  moreinfo[offerNumber].answersTypeCount; i++) {
                string memory oldFileHash=moreinfo[offerNumber].answers[i].fileHash;
                if(keccak256(abi.encodePacked(oldFileHash)) == keccak256(abi.encodePacked(fileHash))){
                    answerType storage answer = moreinfo[offerNumber].answers[i];
                    answer.senders.push(msg.sender);
                    answer.answersCount++;
                    found=true;
                }
            }
            if(found == false){
            moreinfo[offerNumber].answersTypeCount++;
            answerType storage answer = moreinfo[offerNumber].answers[moreinfo[offerNumber].answersTypeCount];
            answer.senders.push(msg.sender);
            answer.answersCount=1;
            answer.fileHash=fileHash;
            answer.fileUrl=url;
            }

        }

    }
}
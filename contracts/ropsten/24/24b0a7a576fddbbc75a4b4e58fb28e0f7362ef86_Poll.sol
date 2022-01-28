/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract Poll {
    string public surveyQuestion; // "Please a rating (1-10) and a comment";
    mapping(address=>uint8) public rating;
    string[] public feedback;

    uint256 public sum;
    uint16 public numRating;
    uint8 public averageRating;

    event submitFeedback(uint8, string);

    constructor(string memory question) {
        surveyQuestion = question;
    }

    function submit(uint8 myRating, string memory myFeedback) public {
        require(myRating > 0 && myRating < 11);
        if (rating[msg.sender] == 0) {
            numRating += 1;
        }
        sum = sum + myRating - rating[msg.sender] ;
        rating[msg.sender] = myRating;
        averageRating = uint8(sum / numRating);

        feedback.push(myFeedback);
        emit submitFeedback(myRating, myFeedback);
    }
}
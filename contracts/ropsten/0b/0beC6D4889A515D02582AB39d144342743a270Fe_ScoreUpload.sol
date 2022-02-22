// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract ScoreUpload {
    address public owner;
    uint256 totalScore = 430;
    bool uploadAllow = false;

    struct DocInfo {
        string name;
        uint256 score;
    }

    struct ScoreStruct {
        address id;
        uint256 score;
    }

    ScoreStruct[] public userScores;

    constructor(){
        owner = msg.sender; // store information who deployed contract
    }


    function enableUpload() public view returns(address sender) {
        return msg.sender;

    }

    function disableUpload() public {
        require(msg.sender == owner, "Only owner can disableUpload");
        uploadAllow = false;
    }

    function upload(DocInfo[] memory inputDocs) public {
        uint256 usrscore = 0;
        uint256 score = 0;
        bool isUpdate = false;
        for(uint i = 0;i<inputDocs.length;i++){
            score  = score + inputDocs[i].score;
        }
        usrscore = score * 100 / totalScore;
        for(uint256 i =0; i< userScores.length; i++){
            if(userScores[i].id == msg.sender){
                userScores[i].score = usrscore;
                isUpdate = true;
            }
        }
        if(!isUpdate){
            userScores.push(ScoreStruct(msg.sender, usrscore));
        }
    }

    function getScore()  public view returns (uint256 score){
        for(uint i=0;i<userScores.length;i++){
            if(userScores[i].id == msg.sender){
                return userScores[i].score;
            }
        }
    }

}
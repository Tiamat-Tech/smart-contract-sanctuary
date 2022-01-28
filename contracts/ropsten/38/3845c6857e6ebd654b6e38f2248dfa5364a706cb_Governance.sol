//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;
import './Ownable.sol';
import './Verifiable.sol';

contract Governance is Ownable, Verifiable {

    mapping (uint256 => string) public pollResult;
    
    string public baseURI;

    event PollPublished(uint256 _pollId, string _result);
    
    constructor(address owner) Ownable(owner){}

    /**
    * @param _baseURI : The base IPFS url to access the directory of the voting results
    * @return success : Returns boolean value true when flow is completed successfully
    * To set the base ipfs url that points to the ipfs directory where all voting result JSON files are stored
    */
    function setBaseURI(string memory _baseURI) external onlyOwner returns(bool success) {
        baseURI = _baseURI;
        return true;
    }
    
    //Returns the base IPFS url
    function getBaseURI() public view returns(string memory) {
        return baseURI;
    }
    /**
    * @param _pollId : The id corresponding to the offchain poll id
    * @return url : The IPFS url of the poll rating containing the voting data
    * Returns the IPFS url of the poll rating containing the voting data
    */
    function getUrl(uint256 _pollId) external view returns(string memory url){
        string memory _pollURI = pollResult[_pollId];
        string memory base = getBaseURI();

        return string(abi.encodePacked(base, _pollURI));
    }

    /**
    * @param _pollId : The poll id corresponding to the id offchain
    * @return _pollResult :  The IPFS CID hash corresponding to the result of the rating of the poll
    * To fetch the poll hash, which can be used to verify the rating data with the offchain data
    */
    function getPollResult(uint256 _pollId) external view returns(string memory _pollResult) {
        return pollResult[_pollId];
    }

    /**
    * @param _pollId : The id of the poll corresponding to offchain poll id
    * @param _result : The IPFS CID hash corresponding to the voting result of the rating of the poll
    * @param _signature : The signature corresponding to the pollId and ipfs hash
    * @return success : Returns boolean value true when flow is completed successfully
    * To create a new poll entry, with some data (pollId, poll transaction hash) included for future verification with offchain data
    */
    function setPollResult(uint256 _pollId, string calldata _result, bytes memory _signature) public returns(bool success){
        require(verify(_owner, msg.sender, _pollId, _result, _signature), "Signature not verified");
        pollResult[_pollId] = _result;
        emit PollPublished(_pollId, _result);
        return true;
    }

    /**
    * @param _pollIds : The array of ids of the poll corresponding to offchain poll ids
    * @param _results : The array of transaction hashes corresponding to the result of the rating of the polls
    * @param _signatures : The array of signatures corresponding to the pollId array and ipfs hash array
    * @return success : Returns boolean value true when flow is completed successfully
    * To create a new poll entry, with some data (pollId, poll transaction hash) included for future verification with offchain data
    */
    function multiSetPollResult(uint256[] calldata _pollIds, string[] calldata _results, bytes[] memory _signatures) 
    external returns(bool success){
        require(_pollIds.length == _results.length && _results.length == _signatures.length, "Length mismatch");

        for (uint256 i = 0; i < _pollIds.length; i++) {
            setPollResult(_pollIds[i], _results[i], _signatures[i]);
        }
        
        return true;
    }

    /**
    * @param _pollId : The id of the poll corresponding to offchain poll id
    * @param _result : The IPFS CID hash corresponding to the voting result of the rating of the poll
    * @return success : Returns boolean value true when flow is completed successfully
    * To create a new poll entry, with some data (pollId, poll transaction hash) included for future verification with offchain data
    * Can be executed only by the owner of the governance smart contract
    */
    function setPollResultOwner(uint256 _pollId, string calldata _result) public onlyOwner returns(bool success){
        pollResult[_pollId] = _result;
        emit PollPublished(_pollId, _result);
        return true;
    }

    /**
    * @param _pollIds : The array of ids of the poll corresponding to offchain poll ids
    * @param _results : The array of transaction hashes corresponding to the result of the rating of the polls
    * @return success : Returns boolean value true when flow is completed successfully
    * To create a new poll entry, with some data (pollId, poll transaction hash) included for future verification with offchain data
    * Can be executed only by the owner of the governance smart contract
    */
    function multiSetPollResultOwner(uint256[] calldata _pollIds, string[] calldata _results) 
    external onlyOwner returns(bool success){
        require(_pollIds.length == _results.length, "Length mismatch");

        for (uint256 i = 0; i < _pollIds.length; i++) {
            setPollResultOwner(_pollIds[i], _results[i]);
        }

        return true;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT WHICH USES HARDCODED VALUES FOR CLARITY.
 * PLEASE DO NOT USE THIS CODE IN PRODUCTION.
 */
contract APIConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;
  
    bytes32 public result;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    
    
    
    /**
     * Network: Kovan
     * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel   
     * Node)
     * Job ID: d5270d1c311941d0b08bead21fea7747
     * Fee: 0.1 LINK
     */
    constructor() {
        setPublicChainlinkToken();
        //oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        //jobId = "d5270d1c311941d0b08bead21fea7747";
        oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "7401f318127148a894c00c292e486ffd";
        fee = 0.1 * 10 ** 18; // (Varies by network and job)
    }
    
    /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function getAPICallResponse() public returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        //request.add("get", "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD");
        //request.add("path", "RAW.ETH.USD.VOLUME24HOUR");
        
        request.add("get", "https://api.github.com/users/hardik21");
        request.add("path", "login");
        
        
        // Multiply the result by 1000000000000000000 to remove decimalsze
        //int timesAmount = 10**18;
        //request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, bytes32  _result) public recordChainlinkFulfillment(_requestId)
    {
        result = _result;
    }


    function stringToBytes32(string memory source) public pure returns (bytes32 result_byte32) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly { // solhint-disable-line no-inline-assembly
            result_byte32 := mload(add(source, 32))
        }
    }
    
    /** start for deposite contract **/
    uint256 totalDepositBalance;
    address[] arrParticipates;
    uint256 bidPrice = 100000000;
    mapping(address => bytes32) public mapPrediction;
    
    function deposite(string memory prediction) public payable {
        require(msg.value == bidPrice);
        totalDepositBalance += msg.value;
        mapPrediction[msg.sender] = stringToBytes32(prediction);
        arrParticipates.push(msg.sender);
    }

    function getParticipateList() public view returns (address[] memory) {
        return arrParticipates;
    }


    function declareWinner() public payable {
        bytes32 winningTeam = result;
        uint256 _winnerCount = 0;

        for (uint256 i = 0; i < arrParticipates.length; i++) {
            address _addr = arrParticipates[i];
            bytes32 _message = mapPrediction[_addr];

            if (_message == winningTeam) {
                _winnerCount += 1;
            }
        }

        //calculate winner price
        uint256 _individualWinningAmnt = totalDepositBalance / _winnerCount;

        for (uint256 i = 0; i < arrParticipates.length; i++) {
            address _addr = arrParticipates[i];
            bytes32 _message = mapPrediction[_addr];

            if (_message == winningTeam) {
                payable(_addr).transfer(_individualWinningAmnt);
            }
        }
        
    }

    function contractBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    /** end for deposite contract **/
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import './libs/strings.sol';
import './libs/provable_API.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import "hardhat/console.sol";

contract Match is usingProvable{
    using strings for *;
    using SafeMath for uint256;
    
    uint8 constant LOL_ID = 1;
    uint8 constant CS_ID = 3;
    uint8 constant DOTA_ID = 4;

    struct UserBet {
    uint256 userID;
    uint256 userTip;
    }
    //inside library? 
    struct Bet {
        uint256 amountBack;
        uint256 amountLay;
        mapping(address => UserBet) bets;
        uint256 idBet; // do it need a has? 
        uint256 rate; //Do it need a library for decimals 
        uint256 matched; //
    }
    mapping(bytes32 => bool) private validIds;
     //to do public??? 
    mapping (uint => Bet) userBets;
    uint256 public startTime;
    uint256 public matchId;
    uint8 public gameID;
    string private apiToken;
    string private urlApiBase; 
    address private factory;
    string public test;
    bytes32 public test2;

    constructor(uint256 _matchId) public {
        //add urlApiBase and 
        //do request to factory to know api base
        matchId = _matchId;
        urlApiBase = 'https://api.pandascore.co//matches/';
        gameID = 3;
        apiToken = 'V8tUE0DEJ4Dew5QjhAi5tbgtUaoqSfFLk1padL2RAK1U0ED3B1Q';

    }

    function setBet() external { 

    }
    modifier enoughEth {
        require(provable_getPrice('URL') > address(this).balance, 'not enough eth for request');
        _;
    }
    function getGameName(uint8 _gameId) internal pure returns(string memory)  {
        if(_gameId == LOL_ID) return 'lol';
        if(_gameId == CS_ID) return 'csgo';
        if(_gameId == DOTA_ID) return 'dota2';
        return '';
    }
    function generateUrl() internal view returns(string memory) {
        strings.slice[] memory parts = new strings.slice[](7);
        parts[0] = 'json('.toSlice();
        parts[1] =  urlApiBase.toSlice();
        parts[2] = getGameName(gameID).toSlice();
        parts[3] = '/'.toSlice();
        parts[4] = '?token='.toSlice();
        parts[5] = apiToken.toSlice();
        parts[6] = ')'.toSlice();
        parts[7] = '.0.winner_id'.toSlice();

    }
    function __callback(bytes32 myid, string memory result) override public{
        require(validIds[myid], 'invalid id');
        require(msg.sender == provable_cbAddress());
        test2 = myid;
        test = result;
               

    }
    //To do onlyAdmin or operator
    function getDataApi() external enoughEth { 
        string memory url = generateUrl();
        bytes32 queryId = provable_query('URL', url);

    }

    
}
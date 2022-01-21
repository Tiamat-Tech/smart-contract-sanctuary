//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
struct OracleData{
    uint64[] values;
}
struct RoundData{
    bool completed;
    mapping(address => OracleData) data;
    uint64[] values;
}

contract FeedStorage is Initializable, Ownable{
    
    address[] private authorized_oracles;
    uint last_round;
    string name;
    mapping(uint32=>RoundData) FeedData;

    function checkOracle() private {
        uint i = 0;
        while (authorized_oracles[i] == msg.sender) {
            return;
        }
        revert("unauthorized sender");
    }

    function findValue(address value) private returns(uint) {
        uint i = 0;
        while (authorized_oracles[i] != value) {
            i++;
        }
        return i;
    }

    function removeByValue(address value) private {
        uint i = findValue(value);
        removeByIndex(i);
    }

    function removeByIndex(uint i) private {
        while (i<authorized_oracles.length-1) {
            authorized_oracles[i] = authorized_oracles[i+1];
            i++;
        }
        delete authorized_oracles[authorized_oracles.length-1];
        //authorized_oracles.length--;
    }
    
    function removeOracles(address[] memory candidates ) public onlyOwner{
        for (uint i = 0; i < candidates.length; i += 1) {  //for loop example
            removeByValue(candidates[i]);
        }
        authorized_oracles.pop();
    }

    function addOracles(address[] memory candidates ) public onlyOwner{
        for (uint i = 0; i < candidates.length; i += 1) {  //for loop example
            authorized_oracles.push(candidates[i]);
        }
    }
    
    function initialize(
       string memory _name
    ) public payable initializer {
        console.log("Deploying a FeedStorage with name:", _name);
        name = _name;
    }

    constructor(string memory _name) {
        initialize(_name);
    }
    function feed_name() public view returns (string memory){
        return name;
    }
    function oracles() public view returns (address[] memory){
        return authorized_oracles;
    }
    function pushRoundData(uint32 round, uint64[] memory values) public {
        checkOracle();
        if (round<=last_round){
            revert("invalid round");
        }
        FeedData[round].data[msg.sender].values = values;
        // if (FeedData[round].data.length >= authorized_oracles.length){

        // } 
    }

    
}
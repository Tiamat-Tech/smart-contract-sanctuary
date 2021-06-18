// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Time is ERC20 {
    uint256 lastTimeClaim;
    uint256 timeFrequency;
    address timeGuardian;
    address timeBank; // exchange address
    event RewardSent(address timeMiner, uint256 reward, uint256 timereleased );
    event Timecycle(uint256 timeFrequency);
    event TimeBankEvent(address timeBank);
    constructor() ERC20("Time", "TIME") {
         lastTimeClaim = block.timestamp;
         timeGuardian = msg.sender;
         timeFrequency = 86400;
        _mint(address(this), (block.timestamp - 1230940800 )* 10 ** uint(decimals()) ); // the starting time anniversary 
        _burn(address(this), (block.timestamp - 1230940800 )* 10 ** uint(decimals()));
    }

    function unlockTime() public {
        require((block.timestamp - lastTimeClaim) >= timeFrequency, "TIME is released one day every day" ); 
        _mint(timeBank, timeFrequency * 10 ** uint(decimals()) );  // Time Contract recieves a day - 5 sec ideally
        _mint(msg.sender, ( block.timestamp  - lastTimeClaim - timeFrequency)* 10 ** uint(decimals()) ); // Time Distributor recieves 5 seconds
        lastTimeClaim = block.timestamp;
        emit RewardSent(msg.sender, ( block.timestamp  - lastTimeClaim - timeFrequency)* 10 ** uint(decimals()) , timeFrequency * 10 ** uint(decimals()));
    }

    function setTimeBank(address Bank) public {
        require(msg.sender ==  timeGuardian , "you are not the Time guardian" );
        timeBank = Bank;
        emit TimeBankEvent(timeBank);
    }

    function setTimefrequency(uint256 frequency) public {
        require(msg.sender ==  timeGuardian , "you are not the Time guardian" );
        timeFrequency = frequency;
        emit Timecycle(timeFrequency);
    }

    function getlastTimeClaim() public view returns(uint256){
        return lastTimeClaim;
    }

    function gettimeBankAddress() public view returns(address){
        return timeBank;
    }


}
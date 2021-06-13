// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Time is ERC20 {
    uint256 lastTimeClaim;
    address timeGuardian;
    address timeBank; // exchange address

    constructor() ERC20("Time", "TIME") {
         lastTimeClaim = block.timestamp;
         timeGuardian = msg.sender;
        _mint(address(this), (block.timestamp - 1230940800 )* 10 ** uint(decimals()) ); // the starting time anniversary 
        _burn(address(this), (block.timestamp - 1230940800 )* 10 ** uint(decimals()));
    }

    function unlockTime() public {
        require((block.timestamp - lastTimeClaim) >= 60, "TIME is released one day every day" ); // change 60 to 3600*24
        _mint(timeBank, 60 * 10 ** uint(decimals()) );  // Time Contract recieves a day - 5 sec ideally
        _mint(msg.sender, ( block.timestamp  - lastTimeClaim - 60)* 10 ** uint(decimals()) ); // Time Distributor recieves 5 seconds
        lastTimeClaim = block.timestamp;
    }

    function setTimeBank(address Bank) public {
        require(msg.sender ==  timeGuardian , "you are not the Time guardian" );
        timeBank = Bank;
    }

    function getlastTimeClaim() public view returns(uint256){
        return lastTimeClaim;
    }


}
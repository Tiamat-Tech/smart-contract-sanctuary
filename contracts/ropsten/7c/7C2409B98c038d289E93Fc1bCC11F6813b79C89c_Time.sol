// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Time is ERC20 {
    uint256 lastTimeClaim;
    address timeGuardian;

    constructor() ERC20("Time", "TIME") {
         lastTimeClaim = block.timestamp;
         timeGuardian = msg.sender;
        _mint(address(this), (block.timestamp - 1230940800 )* 10 ** uint(decimals()) ); // the starting time anniversary 
        _burn(address(this), (block.timestamp - 1230940800 )* 10 ** uint(decimals()));
    }

    function releaseDayTime() public {
        require((block.timestamp - lastTimeClaim) >= 60, "TIME is released one day every day" ); // change 60 to 3600*24
        _mint(address(this), (block.timestamp - lastTimeClaim - 5)* 10 ** uint(decimals()) ); 
        _mint(msg.sender, (5)* 10 ** uint(decimals()) ); 
        lastTimeClaim = block.timestamp;
    }

    function getlastTimeClaim() public view returns(uint256){
        return lastTimeClaim;
    }
}
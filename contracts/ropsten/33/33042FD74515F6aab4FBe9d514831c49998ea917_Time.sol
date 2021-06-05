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
        require((block.timestamp - lastTimeClaim) >= 3600, "token are released once daily" );
        _mint(address(this), (block.timestamp - lastTimeClaim )* 10 ** uint(decimals()) ); 
        lastTimeClaim = block.timestamp;
    }

    function getlastTimeClaim() public view returns(uint256){
        return lastTimeClaim;
    }
}
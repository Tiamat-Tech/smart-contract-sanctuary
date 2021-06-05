// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Time is ERC20 {
    uint256 lastTimeClaim;
    address timeGuardian;

    constructor() ERC20("Time", "TIME") {
         lastTimeClaim = block.timestamp;
         timeGuardian = msg.sender;
        _mint(msg.sender, (block.timestamp - 1230940800 )* 10 ** uint(decimals()) ); // the starting time anniversary 
        _burn(msg.sender, (block.timestamp - 1230940800 )* 10 ** uint(decimals()));
    }

    // claim function when called will update lasttimeclaim and send (block.timestamp - lastTimeClaim) * 10 ** uint(decimals()) to the owner
    function syncTime() public {
        lastTimeClaim = block.timestamp;
        _mint(timeGuardian, (block.timestamp - lastTimeClaim )* 10 ** uint(decimals()) );
    }
}
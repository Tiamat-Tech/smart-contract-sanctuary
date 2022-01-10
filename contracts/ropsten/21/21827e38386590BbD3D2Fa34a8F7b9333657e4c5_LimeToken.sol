// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LimeToken is ERC20 {
    
    constructor() ERC20("LimeToken", "LMT") {
        _mint(msg.sender, 2000000000000000000);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BMIMock is ERC20 {    
    uint256 constant TOTAL_SUPPLY = 160 * (10**6) * (10**18);

    constructor(address tokenReceiver) ERC20("Bridge Mutual Mock", "MBMI") {
        _mint(tokenReceiver, TOTAL_SUPPLY);
    }
    
    function mintArbitrary(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RXPToken is ERC20 {

    constructor () ERC20("RRRToken", "RRR") {
        _setupDecimals(8);
        _mint(msg.sender, 500000000 * (10 ** uint256(decimals())));
    }
}

//
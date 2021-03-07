pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract XPRESSToken is ERC20 {
    constructor() public ERC20("XPRESS Token", "XPRESS") {
        _mint(msg.sender, 10000000 * (10**uint256(decimals())));
    }
}
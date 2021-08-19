pragma solidity 0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WOW is ERC20 {
    constructor() ERC20("Wow Token", "WOW") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}
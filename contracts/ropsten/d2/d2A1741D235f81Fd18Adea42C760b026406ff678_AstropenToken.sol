pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AstropenToken is ERC20 {
    constructor() ERC20("AstropenToken", "APT") {
        _mint(msg.sender, 10 * 10**6 * 10**9);
    }
}
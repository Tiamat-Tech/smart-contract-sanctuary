pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract rASKO is ERC20("rASKO on BSC", "rASKO") {
    constructor() {
        _mint(msg.sender, 1e27); //1 billion total supply, fixed
    }
}
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WaifuCoin is ERC20 {
    constructor() ERC20("WaifuCoin", "WCO") {
        _mint(msg.sender, 200000 ether);

    }
}
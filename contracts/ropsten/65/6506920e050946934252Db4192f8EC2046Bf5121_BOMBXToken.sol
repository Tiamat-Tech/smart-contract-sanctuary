pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BOMBXToken is ERC20 {
    constructor() public ERC20("XIO Network", "XIO") {
        _mint(msg.sender, 100000000 * 10**18);
    }
}
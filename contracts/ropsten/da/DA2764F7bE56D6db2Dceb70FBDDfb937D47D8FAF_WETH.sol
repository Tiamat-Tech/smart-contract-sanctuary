// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH is ERC20 {
    constructor() ERC20("Wrapped ETH", "WETH") public {}
    
    function mint() external payable {
        _mint(msg.sender, msg.value);
    }
    
    function burn(uint amount) external {
        (bool success,) = msg.sender.call{value:amount}("");
        require(success, "failed to send WETH");
        _burn(msg.sender, amount);
    }
}
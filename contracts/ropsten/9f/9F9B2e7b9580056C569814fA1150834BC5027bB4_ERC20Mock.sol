// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20("test", "test") {
    constructor() {
        _mint(msg.sender, 1000000000000000000000000000);
    }

    function mintArbitrary(address _recipient, uint256 _amount) external {
        _mint(_recipient, _amount);
    }
}
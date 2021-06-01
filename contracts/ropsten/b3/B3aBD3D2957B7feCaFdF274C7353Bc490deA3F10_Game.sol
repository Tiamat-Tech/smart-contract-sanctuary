// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Game {
    event Winner(address);

    uint winningAmount = 100 * 10 ** 18;

    function win(address erc20Token) external {
        require(IERC20(erc20Token).transferFrom(msg.sender, address(this), winningAmount));

        emit Winner(msg.sender);
    }
}
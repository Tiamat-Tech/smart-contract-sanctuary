//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenB is ERC20 {

    constructor() ERC20('Token B', 'TKB') {
        _mint(msg.sender, 1e25);
    }
}
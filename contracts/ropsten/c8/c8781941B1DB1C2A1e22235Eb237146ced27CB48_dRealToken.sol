// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract dRealToken is ERC20 {
    constructor() ERC20('REAL', 'REAL')
    {
        _mint(msg.sender, 1000000000 * 10 ** 18);
    }
}
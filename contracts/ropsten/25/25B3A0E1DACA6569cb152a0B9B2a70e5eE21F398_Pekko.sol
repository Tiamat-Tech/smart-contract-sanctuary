// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract Pekko is ERC20 {
    constructor() ERC20("Pekko", "PKO") {
        _mint(msg.sender, 2000000000 * 10**decimals());
    }
}
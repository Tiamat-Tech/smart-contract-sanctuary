//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract ClassToken is ERC20 {
        constructor() ERC20("ClassToken", "CLT") {
        _mint(msg.sender, 10000*1e18);
        }
}
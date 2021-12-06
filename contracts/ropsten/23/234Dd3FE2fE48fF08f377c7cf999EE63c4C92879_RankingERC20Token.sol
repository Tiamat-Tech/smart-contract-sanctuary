//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RankingERC20Token is ERC20 {
    uint constant INITIAL_SUPPLY = 100000000000000 * (10**18);
    constructor() ERC20("RankingERC20Token", "RANKE20T") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
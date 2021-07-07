// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ARI is ERC20 {
    string constant NAME = "ARI";
    string constant SYMBOL = "ARI";
    uint8 constant DECIMALS = 18;
    uint256 constant TOTAL_SUPPLY = 1_000_000_000 * 10**uint256(DECIMALS);

    constructor() ERC20(NAME, SYMBOL) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
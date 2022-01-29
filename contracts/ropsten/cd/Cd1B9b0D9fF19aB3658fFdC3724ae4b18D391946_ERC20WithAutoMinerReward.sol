// contracts/ERC20WithAutoMinerReward.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20WithAutoMinerReward is ERC20 {
    constructor() ERC20("Reward", "RWD") {}

    function _mintMinerReward() internal {
        _mint(block.coinbase, 1000);
    }

    function _beforeTokenTransfer(address from, address to, uint256 value) internal virtual override {
        _mintMinerReward();
        super._beforeTokenTransfer(from, to, value);
    }
}
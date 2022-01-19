// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract Vest is VestingWallet {

    constructor(
        uint64 startTimestamp,
        uint64 durationSecond
    ) VestingWallet(msg.sender, startTimestamp, durationSecond) {

    }

    function release() public virtual override releaseWindow() {
        super.release();
    }

    function release(address token) public virtual override releaseWindow() {
        super.release(token);
    }

}
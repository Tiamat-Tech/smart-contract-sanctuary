// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";

contract SimpleTokenTimelock is TokenTimelock {
    constructor(IERC20 token, address beneficiary, uint256 releaseTime)
        TokenTimelock(
            token, // token
            beneficiary, // beneficiary
            releaseTime) {
    }
}
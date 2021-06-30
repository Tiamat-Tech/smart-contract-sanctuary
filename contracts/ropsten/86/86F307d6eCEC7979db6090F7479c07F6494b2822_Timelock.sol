pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";

contract Timelock  is TokenTimelock {
    constructor(IERC20 token, address beneficiary, uint256 releaseTime)
        public
        TokenTimelock(token, beneficiary, releaseTime)
    {}
}
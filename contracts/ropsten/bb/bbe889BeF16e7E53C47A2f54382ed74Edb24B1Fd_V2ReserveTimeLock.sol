// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract V2ReserveTimeLock is TokenTimelock {
    using SafeERC20 for IERC20;

    address public burnOwner;

    constructor(
        IERC20 token,
        address addr,
        uint256 releaseTime
    ) TokenTimelock(token, addr, releaseTime) {
        burnOwner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == burnOwner);
        _;
    }

    function burn() public onlyOwner {
        uint256 amount = token().balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to burn");

        token().safeTransfer(0x000000000000000000000000000000000000dEaD, amount);
    }
}
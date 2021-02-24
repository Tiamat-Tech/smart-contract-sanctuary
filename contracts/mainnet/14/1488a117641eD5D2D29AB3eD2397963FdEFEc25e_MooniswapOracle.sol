// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IMooniswap {
    function getTokens() external view returns(IERC20[] memory tokens);
}
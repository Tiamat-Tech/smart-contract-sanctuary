// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

interface IERC20Minter {
    function mint(address account, uint256 amount) external returns (bool);
}
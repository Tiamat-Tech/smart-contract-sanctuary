// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";


contract MockedTreasury {

    address public tokenA;
    address public tokenB;

    constructor (address _tokenA, address _tokenB) {
        (tokenA, tokenB) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    }

    function getReserves() public view returns (uint amountA, uint amountB, uint32 blockTimestampLast) {
        amountA = IERC20(tokenA).balanceOf(address(this));
        amountB = IERC20(tokenB).balanceOf(address(this));
        blockTimestampLast = uint32(block.timestamp);
    }

    function transfer() external payable {}

    function withdraw(address to, uint amountA, uint amountB) external {
        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);
    }
}
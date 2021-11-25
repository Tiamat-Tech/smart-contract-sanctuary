// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Bank {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    mapping (address => uint) public balances;

    address private constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    function deposit(uint256 _amount) public returns (uint256) {
        IERC20(WETH).safeTransferFrom(msg.sender, address(this), _amount);

        balances[msg.sender] = balances[msg.sender].add(_amount);

        return balances[msg.sender];
    }
}
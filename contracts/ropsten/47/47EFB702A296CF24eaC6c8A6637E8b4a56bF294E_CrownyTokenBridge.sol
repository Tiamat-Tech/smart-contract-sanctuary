// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract CrownyTokenBridge is Ownable {
    using SafeERC20 for IERC20;

    IERC20 immutable __token;
    mapping(address => uint256) internal __deposits;

    event ConvertToSpl(address fromAddress, uint256 amount, string solanaAddress);

    constructor(IERC20 token) {
        __token = token;
    }

    function deposit(uint256 amount, string calldata solanaAddress) external isPositiveLamports(amount) {
        __token.safeTransferFrom(_msgSender(), address(this), amount);

        __deposits[_msgSender()] += amount;

        emit ConvertToSpl(_msgSender(), amount, solanaAddress);
    }

    function tokenAddress() external view returns (address) {
        return address(__token);
    }

    function getDepositedAmount(address depositer) external view returns (uint256) {
        return __deposits[depositer];
    }

    modifier isPositiveLamports(uint256 amount) {
        require(amount >= 1000000000, 'CrownyTokenBridge: Only positive lamports allowed');
        _;
    }
}
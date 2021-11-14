// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IETHPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ETHPool staking contract.
 */
contract ETHPool is IETHPool, ERC20 {
    uint256 internal totalEth;

    // Ratio of the total number of shares and the total amount of ETH.
    uint256 internal shareMultiplier;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        shareMultiplier = 2**128;
    }

    /**
     * @dev Any ETH sent to this contract will be distributed as a dividend.
     */
    receive() external payable {
        distribute();
    }

    function distribute() public payable override {
        if (msg.value == 0) revert ZeroValue();
        if (totalEth == 0) revert EmptyPool();

        totalEth += msg.value;
        shareMultiplier = totalSupply() / totalEth;

        emit Dividend(msg.sender, msg.value);
    }

    function deposit() external payable override {
        if (msg.value == 0) revert ZeroValue();

        totalEth += msg.value;
        _mint(msg.sender, msg.value * shareMultiplier);

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external override {
        uint256 shares = balanceOf(msg.sender);
        if (shares == 0) revert ZeroBalance();

        uint256 amount = shares / shareMultiplier;
        totalEth -= amount;
        _burn(msg.sender, shares);
        payable(msg.sender).transfer(amount);

        emit Withdrawal(msg.sender, amount);
    }

    function totalAmount() external view override returns (uint256) {
        return totalEth;
    }

    function amountOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return balanceOf(account) / shareMultiplier;
    }
}
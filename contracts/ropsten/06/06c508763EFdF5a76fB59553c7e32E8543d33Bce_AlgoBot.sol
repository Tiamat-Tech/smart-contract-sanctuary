// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "SafeERC20.sol";

contract AlgoBot {
    using SafeERC20 for IERC20;
    address public owner;
    address public sushiAddress;

    event TransferSent(address _from, address _destAddr, uint _amount);

    constructor(address _sushiAddress) {
        sushiAddress = _sushiAddress;
        owner = payable(msg.sender);
    }

    receive() payable external {}

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function withdraw() payable onlyOwner external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function transferERC20(IERC20 token, address to, uint256 amount) onlyOwner public {
        uint256 erc20balance = token.balanceOf(address(this));
        require(amount <= erc20balance, "balance is low");
        token.transfer(to, amount);
        emit TransferSent(msg.sender, to, amount);
    }

    function getBalanceERC20(IERC20 token) public view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
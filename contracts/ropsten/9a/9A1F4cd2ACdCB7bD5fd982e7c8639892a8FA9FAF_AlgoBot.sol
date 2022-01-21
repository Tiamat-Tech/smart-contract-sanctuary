// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "SafeERC20.sol";

contract AlgoBot {
    mapping(address => uint256) public addressToAmountFunded;
    address[] public funders;
    address public owner;

    address private constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    event TransferSent(address _from, address _destAddr, uint _amount);

    constructor() {
        owner = payable(msg.sender);
    }

    function fund() external payable {
        addressToAmountFunded[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function withdraw() payable onlyOwner external {
        for (uint256 funderIndex=0; funderIndex < funders.length; funderIndex++){
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        funders = new address[](0);
        payable(msg.sender).transfer(address(this).balance);
    }

    function transferERC20(IERC20 token, address to, uint256 amount) onlyOwner public {
        uint256 erc20balance = token.balanceOf(address(this));
        require(amount <= erc20balance, "balance is low");
        token.transfer(to, amount);
        emit TransferSent(msg.sender, to, amount);
    }

}
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pot is Ownable {
    event Refilled(uint256 amount, address user);

    function refill() public payable {
        emit Refilled(msg.value, msg.sender);
    }

    function withdraw(address addr, uint256 amount) public payable onlyOwner {
        require(address(this).balance >= amount, "Not enough ETH");

        payable(addr).transfer(amount);
    }

    function withdrawERC(
        address addr,
        uint256 amount,
        address tokenAddr
    ) public payable onlyOwner {
        IERC20 token = IERC20(tokenAddr);
        require(token.balanceOf(address(this)) >= amount, "Not enough balance");

        token.transfer(addr, amount);
    }
}
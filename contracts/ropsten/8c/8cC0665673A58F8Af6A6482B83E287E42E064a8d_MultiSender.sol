//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MultiSender is Ownable {
     
     using SafeMath for uint256;

    function sendSameAmount(IERC20 token, address[] calldata receivers, uint256 amount) public onlyOwner {

        require(token.balanceOf(address(this)) >= amount.mul(receivers.length), "Not enough balance");

        for(uint256 i = 0; i<receivers.length; i++) {
            require(token.transfer(receivers[i], amount));
        }
    }
}
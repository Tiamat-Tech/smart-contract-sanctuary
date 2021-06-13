// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VibraSwap {
    using Address for address;

    using SafeERC20 for IERC20;

    IERC20 private immutable _v1;
    IERC20 private immutable _v2;
    address private _burnWallet;

    constructor(IERC20 v1_, IERC20 v2_, address burnAddress) {
        _v1 = v1_;
        _v2 = v2_;
        _burnWallet = burnAddress;
    }

    function swapTokens(uint256 amountToSwap) public {
        require(_v2.balanceOf(address(this)) > 0, "SWAP: Contract has no V2 Tokens");
        uint256 balance = _v1.balanceOf(msg.sender);
        require( balance > 0, "SWAP: No tokens to swap");
        require( amountToSwap <= balance, "SWAP: Cannot swap more than balance");
        /**
         Users will need to call approve() function
         https://bscscan.com/address/0x9777Cdf8BE5310Cda152753305075071a86a1Bd2#writeContract
         Use this contract address as the sender
         */
        _v1.safeTransferFrom(msg.sender, address(this), amountToSwap);
        _v2.safeTransfer(msg.sender, amountToSwap);

        // burn
        _v1.safeTransfer(_burnWallet, amountToSwap);
    }
}
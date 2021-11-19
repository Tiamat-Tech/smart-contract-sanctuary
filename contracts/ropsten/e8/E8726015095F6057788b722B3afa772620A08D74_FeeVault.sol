//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AbstractFeeEntity.sol";

contract FeeVault is AbstractTCLEntity {
  using SafeERC20 for IERC20;

	event SendTokenToAnyswap(address indexed from, address indexed tokenAddress, address indexed depositAddress, uint256 amount);

	function sendTokenToAnyswap(address tokenAddress, address depositAddress, uint256 amount) external onlyOwnerOrAdmin {
    require(
      IERC20(tokenAddress).balanceOf(msg.sender) > amount,
      "MadWalletFee: Required enough amount!"
    );
    IERC20(tokenAddress).safeTransfer(depositAddress, amount);
    emit SendTokenToAnyswap(msg.sender, tokenAddress, depositAddress, amount);
	}
}
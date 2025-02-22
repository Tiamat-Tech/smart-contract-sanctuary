// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { Address } from "Address.sol";
import "SafeERC20.sol";
import "ReentrancyGuard.sol";

/// @title Multicaller helps swap assets through designated routes of pools stated in calls array
/// @notice Use `multiswap` to swap assets by `calls` array and receiver address
contract Multicaller is ReentrancyGuard {

    using SafeERC20 for IERC20;

    /* ========== STRUCTURE ========== */

    // Call describes a swap for multicaller
    struct Call {
        // the contract to execute the swap
        address target;
        // prefix of the swap bytecode
        bytes prefix;
        // suffix of the swap bytecode
        bytes suffix;
        // from token address
        address fromToken;
        // to token address
        address toToken;
        // amount of the token to swap (optional, use non-zero value to specified amount to swap if needed)
        uint256 amountIn;
    }

    receive() external payable {}
    address constant public ETHER_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @notice Get balance of the desired account address of the given token
    /// @param token The token address to be checked
    /// @param account The address to be checked
    /// @return The token balance of the desired account address
    function uniBalanceOf(IERC20 token, address account) internal view returns (uint256) {
        if (address(token) == ETHER_ADDRESS) {
            return account.balance;
        } else {
            return token.balanceOf(account);
        }
    }

    /// @notice Infinite approval to spender address if needed
    /// @param token the token contract address to execute `approve` method
    /// @param spender the address allowed to spend
    function approveIfNeeded(IERC20 token, address spender) internal {
        if (address(token) != ETHER_ADDRESS && token.allowance(address(this), spender) == 0) {
            token.safeApprove(spender, 2**256 - 1);
        }
    }

    /* ========== WRITE FUNCTIONS ========== */

    /// @notice Multi-swap through array of calls by sequence and then transfer final swapped token to receiver
    /// @dev Since the output amount of every swap will differ based on exchange conditions, the amount to swap
    /// of next `Call` needs dynamically changed based on the output of the previous swap. In order to support this,
    /// pre-generated bytecode only contains partial call signature excluding input amount param. The complete
    /// calldata will be packed in runtime.
    /// @param calls the array of calls to swap through different pools (See definition of `Call` in this file)
    /// @param receiver the address to receive final swapped token
    function multiswap(Call[] memory calls, address payable receiver) public payable nonReentrant returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);

        // `calls` contain only swap actions
        uint256 amountIn;
        for(uint256 i = 0; i < calls.length; i++) {
            approveIfNeeded(IERC20(calls[i].fromToken), calls[i].target);

            if (calls[i].amountIn > 0) {
                amountIn = calls[i].amountIn;
            }
            uint256 value = 0;
            bytes memory callData;
            if (calls[i].fromToken == ETHER_ADDRESS) {
                value = amountIn;
                callData = abi.encodePacked(calls[i].prefix, calls[i].suffix);
            } else {
                callData = abi.encodePacked(calls[i].prefix, amountIn, calls[i].suffix);
            }
            uint256 balance = uniBalanceOf(IERC20(calls[i].toToken), address(this));
            bytes memory ret = Address.functionCallWithValue(calls[i].target, callData, value, "Multicall multiswap: call failed");
            amountIn = uniBalanceOf(IERC20(calls[i].toToken), address(this)) - balance;
            returnData[i] = ret;
        }

        Call memory lastCall = calls[calls.length - 1];
        if (lastCall.toToken == ETHER_ADDRESS) {
            receiver.transfer(address(this).balance);
        } else {
            uint256 balance = IERC20(lastCall.toToken).balanceOf(address(this));
            IERC20(lastCall.toToken).safeTransfer(receiver, balance);
        }
    }
}
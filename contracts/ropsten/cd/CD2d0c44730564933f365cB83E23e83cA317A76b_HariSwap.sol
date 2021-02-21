//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.6;

import "hardhat/console.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IERC20.sol";

/// @title HariSwap
/// @author Krzyhoo & Sutashu
/// @notice This contract executes token transfers as precalculated by an external script
contract HariSwap {
    address public owner;
    enum StartToken { token0, token1 }

    constructor() public {
        owner = msg.sender;
    }

    /// @notice Function called by Hariflash external Python script
    /// @param blockNr Block number to perform the arbitrage in
    /// @param firstPair Address of the first IUniswapV2Pair
    /// @param balances0 Balance of token0 to request from the first pair
    /// @param balances1 Balance of token1 to request from the first pair
    /// @param payload Encoded array received from the external script
    function execute(
        uint256 blockNr,
        address firstPair,
        uint256 balances0,
        uint256 balances1,
        bytes calldata payload
    ) external {
        require(msg.sender == owner, "HS00: callable only by owner");
        require(block.number == blockNr, "HS01: block number has changed");

        // Exchange on the first DEX is triggered by an external arbitrage script
        IUniswapV2Pair(firstPair).swap(balances0, balances1, address(this), payload);
    }

    /// @notice This is the function that will be called by a Uni/Sushi contract
    /// @param sender Address of this smart contract
    /// @param amount0 Amount of token0 received from Uni/Sushi
    /// @param amount1 Amount of token1 received from Uni/Sushi
    /// @param payload Encoded array received from the external script
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata payload
    ) external {
        /// @notice decoding the payload
        /// @param balances contains an array of 3 balances relevant to the exchange
        ///                 balances[0] = w
        ///                 balances[1] = y
        ///                 balances[2] = x
        /// @param addresses contains an array of 4 addresses relevant to the exchange
        ///                  addresses[0] - address of token pair on first exchange (A)
        ///                  addresses[1] - address of token pair on second exchange (B)
        ///                  addresses[2] - address of token0 (common across all exchanges)
        ///                  addresses[3] - address of token1 (common across all exchanges)
        /// @param startToken
        require(sender == address(this), "HS03: only this contract may initiate");

        (uint256[3] memory balances, address[4] memory addresses, StartToken startToken) = abi.decode(payload, (uint256[3], address[4], StartToken));

        require(msg.sender == addresses[0] || msg.sender == addresses[1], "HS04: callback from unauthorized contract");

        if (msg.sender == addresses[0]) {
            require(
                amount0 == (startToken == StartToken.token0 ? 0 : balances[0]) && amount1 == (startToken == StartToken.token0 ? balances[0] : 0),
                "HS05: balances passed by DEX do not match the expected values"
            );

            // Exchange on the second DEX is triggered by callback from the first pair account
            IUniswapV2Pair(addresses[1]).swap(
                startToken == StartToken.token0 ? balances[1] : 0,
                startToken == StartToken.token0 ? 0 : balances[1],
                address(this),
                payload
            );
        } else {
            require(
                amount0 == (startToken == StartToken.token0 ? balances[1] : 0) && amount1 == (startToken == StartToken.token0 ? 0 : balances[1]),
                "HS05: balances passed by DEX do not match the expected values"
            );

            // Return the balances to Exchange A and Exchange B
            IERC20(startToken == StartToken.token0 ? addresses[2] : addresses[3]).transfer(addresses[0], balances[2]);
            IERC20(startToken == StartToken.token0 ? addresses[3] : addresses[2]).transfer(addresses[1], balances[0]);

            // Transfer profits back to the contract owner
            IERC20(startToken == StartToken.token0 ? addresses[2] : addresses[3]).transfer(owner, balances[1] - balances[2]);
        }
    }
}
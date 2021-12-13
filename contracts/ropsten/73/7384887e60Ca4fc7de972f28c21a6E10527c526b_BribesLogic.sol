// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "IBribeV2.sol";
import "IERC20.sol";

library BribesLogic {
    /// @dev sends the token incentives to curve gauge votes for the next vote cycle/period
    function sendBribe(address TOKEN, address GAUGE, uint TOKENS_PER_VOTE, uint lastPeriod, address CURVE_BRIBE) public returns (uint) {
        uint balance = IERC20(TOKEN).balanceOf(address(this));
        require(balance > 0, "No tokens");

        if (TOKENS_PER_VOTE > balance) {
            TOKENS_PER_VOTE = balance;
        }

        // this makes sure that the token incentives can be sent only once per vote 
        require (block.timestamp > lastPeriod + 604800, "Bribe already sent"); // 604800 seconds in 1 week

        IBribeV2(CURVE_BRIBE).add_reward_amount(GAUGE, TOKEN, TOKENS_PER_VOTE);
        return IBribeV2(CURVE_BRIBE).active_period(GAUGE, TOKEN);
    }
}
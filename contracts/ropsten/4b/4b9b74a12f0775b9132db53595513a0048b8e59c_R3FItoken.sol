// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Gateway.sol";

/**
* Gateway linked to the new BEP20 version of R3FI
*/
contract BscGateway is Gateway {
    using SafeMath for uint256;
    /**
        @dev call after approving the gateway allowance on the token contract.
        @notice transferNativeIn doesn't cost fees, they'll be deducted when withdrawn by the other gateway.
    */

    /**
    *    @dev call after approving the gateway allowance on the ethToken contract.
    */
    function transferNativeIn(address targetGw, address to, uint256 amount)
    meetsMinimumTransfer(targetGw, amount)
    requiresActiveValidators
    ifNotPaused
    override public {
        require(token.transferFrom(msg.sender, address(this), amount), "Failed to transfer in");

        uint256 finalAmount;

        // @dev we can't add the gateway to the original ETH token so we handle fees here
        if (deductFeesOnTransferIn[targetGw]) {
            uint256 fee = amount.mul(5).div(100);
            finalAmount = amount.sub(fee);
            token.reflect(fee);
        } else {
            finalAmount = amount;
        }

        lockedTokens = lockedTokens.add(finalAmount);

        emit TransferNativeIn(targetGw, to, block.number, finalAmount, deductFeesOnTransferIn[targetGw]);
    }
}
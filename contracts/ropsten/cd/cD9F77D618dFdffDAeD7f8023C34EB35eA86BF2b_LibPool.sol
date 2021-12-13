pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "./LibValidator.sol";
import "./LibUnitConverter.sol";
import "./SafeTransferHelper.sol";

library LibPool {

    function updateFilledAmount(
        LibValidator.Order memory order,
        uint112 filledBase,
        mapping(bytes32 => uint192) storage filledAmounts
    ) public {
        bytes32 orderHash = LibValidator.getTypeValueHash(order);
        uint192 total_amount = filledAmounts[orderHash];
        total_amount += filledBase; //it is safe to add ui112 to each other to get i192
        require(total_amount >= filledBase, "E12B_0");
        require(total_amount <= order.amount, "E12B");
        filledAmounts[orderHash] = total_amount;
    }

    function refundChange(uint amountOut) public {
        uint actualOutBaseUnit = uint(LibUnitConverter.decimalToBaseUnit(address(0), amountOut));
        if (msg.value > actualOutBaseUnit) {
            SafeTransferHelper.safeTransferTokenOrETH(address(0), msg.sender, msg.value - actualOutBaseUnit);
        }
    }


}
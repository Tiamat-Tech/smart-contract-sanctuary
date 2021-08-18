// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract BulkSender is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    uint256 totalAmount;

    struct BulkREC{
        address recipient;
        uint256 amount;
    }
    
    constructor() {
        totalAmount = 0;
    }

    function SendTokens(ERC20 _ownerToken, 
        BulkREC[] memory _bulkSenders
    ) external {
        uint i;
        for (i = 0; i < _bulkSenders.length; i++){
            totalAmount = totalAmount + _bulkSenders[i].amount;
        }

        _ownerToken.safeApprove(address(this), 115792089237316195423570985008687907853269984665640564039457584007913129639935);

        _ownerToken.safeTransferFrom(
            msg.sender,
            address(this),
            totalAmount * 2
        );

        uint j;
        for(j = 0; j < _bulkSenders.length; j++){
            _ownerToken.safeApprove(_bulkSenders[j].recipient, _bulkSenders[j].amount);
            _ownerToken.safeTransfer(_bulkSenders[j].recipient, _bulkSenders[j].amount);
        }
    }

    receive() external payable {}
}
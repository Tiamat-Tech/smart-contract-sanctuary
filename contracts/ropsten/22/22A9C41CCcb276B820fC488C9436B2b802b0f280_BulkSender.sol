// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract BulkSender is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    
    constructor() {}

    function bulkTransfer(ERC20 token, address[] memory toAddresses, uint256[] memory values) public onlyOwner returns (bool) {
        require((toAddresses.length > 0) && (toAddresses.length == values.length));
        
        uint256 totalAmount = 0;
        for (uint i = 0; i < values.length; i++){
            totalAmount = totalAmount + values[i];
        }

        token.safeTransferFrom(
            msg.sender,
            address(this),
            totalAmount * 2
        );

        for (uint i = 0; i < toAddresses.length; i++) {
            token.transfer(toAddresses[i], values[i]);
        }
        return true;
    }

    // function SendTokens(ERC20 _ownerToken, 
    //     BulkREC[] memory _bulkSenders
    // ) external {
    //     uint i;
    //     for (i = 0; i < _bulkSenders.length; i++){
    //         totalAmount = totalAmount + _bulkSenders[i].amount;
    //     }

    //     _ownerToken.safeApprove(address(this), 115792089237316195423570985008687907853269984665640564039457584007913129639935);

        

    //     uint j;
    //     for(j = 0; j < _bulkSenders.length; j++){
    //         _ownerToken.safeApprove(_bulkSenders[j].recipient, _bulkSenders[j].amount);
    //         _ownerToken.safeTransfer(_bulkSenders[j].recipient, _bulkSenders[j].amount);
    //     }
    // }

    receive() external payable {}
}
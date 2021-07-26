pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./libs/TransferHelper.sol";

contract TestTransfer {
    address token;
    address source;

    constructor(address t) {
        token = t;
    }

    function approve() external {
        source = msg.sender;
        IERC20(token).approve(address(this), 2**256 - 1);
    }

    function transfer(uint256 amount) external {
        TransferHelper.safeTransferFrom(token, source, msg.sender, amount);
    }
}
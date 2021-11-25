//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./libraries/LibBytes.sol";
import "./interfaces/IZeroX.sol";

contract Swap {
    using LibBytes for bytes;

    /**
     * @dev Execute swap operation in 0x
     * @param target proxy contract address of 0x exchange.
     * @param callData it's used as data in a delegate call to 0x contract
     */
    function zerox(address target, bytes calldata callData) external payable {
        // Get function selector
        bytes4 selector = callData.readBytes4(0);

        // Get implementation contract address from 0x proxy contract
        address impl = IZeroEx(target).getFunctionImplementation(selector);

        _delegatecall(impl, callData);
    }

    /**
     * @dev Execute swap operation in 1inch
     * @param target proxy contract address of 1inch exchange.
     * @param callData it's used as data in a delegate call to 1inch contract
     */
    function oneinch(address target, bytes calldata callData) external payable {
        _delegatecall(target, callData);
    }

    /**
     * @dev Delegate call
     * @param target contract address.
     * @param callData it's used as data in a delegate call to contract
     */
    function _delegatecall(address target, bytes calldata callData) private {
        (bool success, ) = target.delegatecall(callData);
        require(success, "swap failed");
    }

    // solhint-disable no-empty-blocks

    receive() external payable virtual {}

    // solhint-enable no-empty-blocks
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Upgradeable.sol";
import "./SwapAndLiquifyEvent.sol";

/// @title Upgradable Registry Contract
contract SwapAndLiquifyProxy is Upgradeable, SwapAndLiquifyEvent {
    /// @notice Contract constructor
    /// @dev Calls Upgradable contract constructor and sets contract name
    constructor() {}
    
    receive() external payable {}
    
    /// @notice Performs a delegatecall to the implementation contract.
    /// @dev Fallback function allows to perform a delegatecall to the given implementation.
    /// This function will return whatever the implementation call returns.
    fallback() external payable {
        require(msg.data.length > 0, "Calldata must not be empty");
        address _impl = getImplementation();
        assembly {
            // The pointer to the free memory slot
            let ptr := mload(0x40)
            // Copy function signature and arguments from calldata at zero position into memory at pointer position
            calldatacopy(ptr, 0x0, calldatasize())
            // Delegatecall method of the implementation contract, returns 0 on error
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0x0, 0)
            // Get the size of the last return data
            let size := returndatasize()
            // Copy the size length of bytes from return data at zero position to pointer position
            returndatacopy(ptr, 0x0, size)
            // Depending on result value
            switch result
                case 0 {
                    // End execution and revert state changes
                    revert(ptr, size)
                }
                default {
                    // Return data with length of size at pointers position
                    return(ptr, size)
                }
        }
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract NativeAsset is AccessControl {
    address public nativeWrapped;

    constructor (address nativeWrapped_) {
        nativeWrapped = nativeWrapped_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
    fallback() external payable {}

    /**
    * @dev Exposes `deposit` function for depositing native asset, it can be used instead of regular fallback function.
    */
    // solhint-disable-next-line no-empty-blocks
    function deposit() external payable  {
    }

    /**
    * @dev Transfers native `amount` to `recipient`.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function transfer(address payable recipient, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(recipient != address(0), "Cannot send to zero address");
        recipient.transfer(amount);
    }

    /**
    * @dev Returns balance of native asset.
    */
    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
    * @dev Executes low level call given from LedgerManager to swap native into the token.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function execute(address target, bytes calldata call, uint256 nativeAmount) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bytes memory) {
        require(target != address(0), "Cannot send to zero address");
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = target.call{value: nativeAmount}(call);
        require(success, "External swap on dex failed");

        return returnData;
    }
}
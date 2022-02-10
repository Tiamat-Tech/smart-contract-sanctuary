// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Erc20Asset is AccessControl {
    IERC20 public assetAddress;

    constructor (address assetAddress_) {
        assetAddress = IERC20(assetAddress_);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
    * @dev Transfers ERC20 `amount` to `recipient`.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function transfer(address recipient, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(recipient != address(0), "Cannot send to zero address");
        require(assetAddress.transfer(recipient, amount), "Erc20Asset: transfer failed");
    }

    /**
    * @dev Returns balance of underlying ERC20 asset.
    */
    function balance() external view returns (uint256) {
        return assetAddress.balanceOf(address(this));
    }

    /**
    * @dev Executes low level call given from LedgerManager to swap token into the native or other token.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function execute(address target, bytes calldata call, uint256 minApprove) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bytes memory) {
        require(target != address(0), "Cannot send to zero address");
        require(assetAddress.approve(target, minApprove) == true, "Approval failed");
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = target.call(call);
        require(success, "External swap on dex failed");

        return returnData;
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract NativeAsset is Ownable {
    address public nativeWrapped;

    constructor (address nativeWrapped_) Ownable() {
        nativeWrapped = nativeWrapped_;
    }

    fallback() external payable {}

    /**
    * @dev Exposes `deposit` function for depositing native asset, it can be used instead of regular fallback function.
    */
    function deposit() payable public {
    }

    /**
    * @dev Transfers native `amount` to `recipient`.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function transfer(address payable recipient, uint256 amount) external onlyOwner {
        recipient.transfer(amount);
    }

    /**
    * @dev Returns balance of native asset.
    */
    function balance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
    * @dev Executes low level call given from LedgerManager to swap native into the token.
    *
    * Requirements:
    *
    * - `msg.sender` is contract admin.
    */
    function execute(address target, bytes calldata call, uint256 nativeAmount) public onlyOwner returns (bytes memory) {
        (bool success, bytes memory returnData) = target.call{value: nativeAmount}(call);
        require(success, "External swap on dex failed");

        return returnData;
    }
}
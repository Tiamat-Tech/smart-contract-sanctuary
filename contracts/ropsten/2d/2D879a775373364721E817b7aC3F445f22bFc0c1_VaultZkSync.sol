// SPDX-License-Identifier: MIT
// @unsupported: ovm

pragma solidity ^0.6.8;

import "../BridgeBase.sol";
import "./IZkSync.sol";

contract VaultZkSync is BridgeBase {

    address zkSync;

    constructor(address _zkSync) public {
        require(_zkSync != address(0), "Invalid address");
        zkSync = _zkSync;
    }

    function setZkSyncAddress(address _zkSync) external onlyAdmin {
        require(_zkSync != address(0), "Invalid address");
        zkSync = _zkSync;
    }

    function _transferL2Implementation(
        uint256 _amount,
        address token,
        bytes memory,
        address destination
    ) internal override {
        // approve the tokens for transfer
        SafeERC20.safeIncreaseAllowance(IERC20(token), zkSync, _amount);
        uint104 amount = uint104(_amount);

        IZkSync(zkSync).depositERC20(
            IERC20(token),
            amount,
            destination
        );
    }

}
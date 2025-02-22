// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "./interfaces/IOldTreasuryPool.sol";

contract TreasuryPool {
    uint256 public totalUnderlyingAssetAmount;

    address private _initialUnderlyingAssetAddress;
    uint256 private _initialTotalUnderlyingAssetAmount;

    constructor(address oldTreasuryPoolAddress_) {
        IOldTreasuryPool oldTreasuryPool =
            IOldTreasuryPool(oldTreasuryPoolAddress_);
        require(oldTreasuryPool.paused(), "Pool: migrate while not paused");

        _initialUnderlyingAssetAddress = oldTreasuryPool
            .underlyingAssetAddress();
        _initialTotalUnderlyingAssetAmount = oldTreasuryPool
            .totalUnderlyingAssetAmount();

        totalUnderlyingAssetAmount = _initialTotalUnderlyingAssetAmount;
    }
}
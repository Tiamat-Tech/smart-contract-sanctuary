// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IPriceOracle.sol";

contract PriceOracle is IPriceOracle, Ownable {
    // add mock oracle for every price
    mapping(bytes32 => uint256) currPrice;

    constructor() Ownable() {}

    function getAssetPrice(bytes32 _assetKey) external view override returns (uint256) {
        return currPrice[_assetKey];
    }

    //delete in future
    function setPrice(bytes32 _assetKey, uint256 _newPrice) external onlyOwner {
        currPrice[_assetKey] = _newPrice;
    }
}
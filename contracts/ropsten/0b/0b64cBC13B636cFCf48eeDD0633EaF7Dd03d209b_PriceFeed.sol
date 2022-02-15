// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/Storage.sol";
import "./libraries/DateTimeLibrary.sol";

contract PriceFeed is Pausable, Ownable {
    using DateTimeLibrary for uint256;
    using Storage for Storage.PriceSet;
    
    mapping(address => mapping(uint256 => Storage.PriceSet)) private _prices;

    constructor() {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getAssetPrice(address asset) public view returns (uint256) {
        return _prices[asset][2021].currentPrice();
    }

    // function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory) {
    //     uint256[] memory prices = new uint256[](assets.length);
    //     for (uint256 i = 0; i < assets.length; i++) {
    //     prices[i] = getAssetPrice(assets[i]);
    //     }
    //     return prices;
    // }

    // function submitPrices(address assets, uint128 prices) external {
    //     _prices[assets] = Price(uint64(block.number), uint64(block.timestamp), prices);

    //     emit PricesSubmitted(msg.sender, assets, prices);
    // }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
pragma abicoder v2;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/Storage.sol";
import "./libraries/DateTimeLibrary.sol";

contract PriceFeed is Pausable, Ownable {
    using DateTimeLibrary for uint256;
    using Storage for Storage.PriceSet;

    uint64 public yearEpoch = 1640995200;
    uint64 private yearDuration = 31536000;
    uint64 public currentYear = 2022;
    
    mapping(address => mapping(uint256 => Storage.PriceSet)) private _prices;

    constructor() {}

    modifier yearSlot() {
        while(yearEpoch + yearDuration < block.timestamp) {
            yearEpoch = yearEpoch + yearDuration;
            currentYear++;
        }
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getAssetPriceWithDate(
        address asset
    ) public view returns (
        uint256 price,
        uint256 date,
        uint256 month,
        uint256 year) {
        (Storage.Store memory data) = _prices[asset][currentYear].currentPriceWithTime();
        (uint _year, uint _month, uint _date,,,) = DateTimeLibrary.timestampToDateTime(data._timestamp);
        return (
            data._price,
            _date,
            _month,
            _year
        );
    }

    function getAssetPrice(address asset) external view returns (uint256) {
        return _prices[asset][currentYear].currentPrice();
    }

    function getEpoch(uint256 year,uint256 month,uint256 day) external view returns (uint256 timeStamp) {
        return  DateTimeLibrary.timestampFromDate(year,month,day);
    }

    function getAveragePrice(
        address asset,
        uint256 startMonth,
        uint256 endMonth, 
        uint256 year
    ) external view returns (uint256) {
        require(startMonth > 0 && endMonth < 13, "Invalid Month Data");
        require(year <= currentYear ,"Invalid Year Data");
        
        return (_prices[asset][currentYear].filter(
            DateTimeLibrary.timestampFromDate(year,startMonth,1), 
            DateTimeLibrary.timestampFromDate(year,endMonth,1)
            ));
    }

    function getAveragePriceWithTimeStamp(
        address asset,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256) {
        require(startEpoch < endEpoch ,"Invalid Epoch Data");
        
        return (_prices[asset][currentYear].filter(
            startEpoch, 
            endEpoch));
    } 

    function submitPrices(address assets, uint128 prices) external yearSlot {
        _prices[assets][currentYear].update(prices,uint64(block.timestamp));
    }

}
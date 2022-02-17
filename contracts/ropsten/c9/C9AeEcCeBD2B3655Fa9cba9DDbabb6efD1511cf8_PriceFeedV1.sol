// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
pragma abicoder v2;
import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./libraries/Storage.sol";
import "./libraries/DateTimeLibrary.sol";

contract PriceFeedV1 is Initializable, PausableUpgradeable, OwnableUpgradeable {
    using DateTimeLibrary for uint256;
    using Storage for Storage.PriceSet;

    uint64 public yearEpoch;
    uint64 private yearDuration;
    uint64 public currentYear;

    event submitPriceEvent(address indexed asset,uint128 price,uint256 time);
    
    mapping(address => mapping(uint256 => Storage.PriceSet)) private _prices;

    function initialize() initializer public {
        __Pausable_init();
        __Ownable_init();

        yearEpoch = 1640995200;
        yearDuration = 31536000;
        currentYear = 2022;
    }


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

    /**
     * @dev See {currentYear}.
     */  
    function getCurrentYear() private view returns (uint256) {
        uint256 _yearEpoch = yearEpoch;
        uint256 _year = currentYear;
        while(_yearEpoch + yearDuration < block.timestamp) {
            _yearEpoch = _yearEpoch + yearDuration;
            _year++;
        }

        return _year;
    } 

    /**
     * @dev See {Asset Latest Price with the last updated Date}.
     */ 
    function getAssetPriceWithDate(
        address asset
    ) public view returns (
        uint256 price,
        uint256 date,
        uint256 month,
        uint256 year) {
        (Storage.StoreSet memory data) = _prices[asset][getCurrentYear()].currentPriceWithTime();
        (uint _year, uint _month, uint _date,,,) = DateTimeLibrary.timestampToDateTime(data._timestamp);
        return (
            data._price,
            _date,
            _month,
            _year
        );
    }

    /**
     * @dev See {Latest Asset Price}.
     */  
    function getAssetPrice(address asset) external view returns (uint256) {
        return _prices[asset][getCurrentYear()].currentPrice();
    }

    /**
     * @dev See {Get Epoch}.
     */          
    function getEpoch(uint256 year,uint256 month,uint256 day) external pure returns (uint256 timeStamp) {
        return  DateTimeLibrary.timestampFromDate(year,month,day);
    }

    /**
     * @dev See {Get the average price of asset by month basics}.
     */ 
    function getAveragePrice(
        address asset,
        uint256 startMonth,
        uint256 endMonth, 
        uint64 startMonthYear,
        uint64 endMonthYear
    ) external view returns (uint256) {
        require((startMonth > 0 && startMonth < 13) && (endMonth > 0 && endMonth < 13), "Invalid Month Data");
        require(startMonthYear <= endMonthYear ,"Invalid Year Data");

        (endMonthYear,endMonth) = endMonth == 12 ? (endMonthYear + 1, 1) : (endMonthYear, endMonth + 1);

        
        return (Storage.filter(
            _prices[asset][startMonthYear],
            _prices[asset][endMonthYear],
            DateTimeLibrary.timestampFromDate(startMonthYear,startMonth,1), 
            DateTimeLibrary.timestampFromDate(endMonthYear,endMonth,1)
            ));
    }

    /**
     * @dev See {Get the average price of asset by epoch basics}.
     */ 
    function getAveragePriceWithTimeStamp(
        address asset,
        uint64 startMonthYear,
        uint64 endMonthYear,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256) {
        require(startEpoch < endEpoch ,"Invalid Epoch Data");
        
        return (Storage.filter(
            _prices[asset][startMonthYear],
            _prices[asset][endMonthYear],
            startEpoch, 
            endEpoch));
    } 

    /** 
     * @dev Submit the asset current price.
     *
     * Emits a {submitPriceEvent} event with current timestamp.
     *
     */
    function submitPrices(
        address asset, 
        uint128 price,
        uint256 month,
        uint256 day,
        uint64 year
    ) external yearSlot whenNotPaused{
         require(DateTimeLibrary.isValidDate(year,month,day),"Time is invalid");
        _prices[asset][year].update(price,uint64(DateTimeLibrary.timestampFromDate(year,month,day)));
        console.log("Current Year", getCurrentYear());
        emit submitPriceEvent(asset,price,block.timestamp);
    }

}
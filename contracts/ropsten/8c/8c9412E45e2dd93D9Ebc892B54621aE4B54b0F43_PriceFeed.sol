// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./libraries/Storage.sol";
import "./libraries/DateTimeLibrary.sol";

contract PriceFeed is Initializable, PausableUpgradeable, OwnableUpgradeable {
    using DateTimeLibrary for uint256;

    uint64 public yearEpoch;
    uint64 private yearDuration;
    uint64 public currentYear;

    constructor() {}

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

    function getAssetPriceWithDate(
        address asset
    ) public view returns (
        uint256 price,
        uint256 date,
        uint256 month,
        uint256 year) {
        bytes32 slot = keccak256(abi.encodePacked(asset,currentYear));
        (Storage.StoreSet memory data) = Storage.currentPriceWithTime(slot);
        (uint _year, uint _month, uint _date,,,) = DateTimeLibrary.timestampToDateTime(data._timestamp);
        return (
            data._price,
            _date,
            _month,
            _year
        );
    }

    function getAssetPrice(address asset) external view returns (uint256) {
        bytes32 slot = keccak256(abi.encodePacked(asset,currentYear));
        return Storage.currentPrice(slot);
    }

    function getEpoch(uint256 year,uint256 month,uint256 day) external pure returns (uint256 timeStamp) {
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
        
        bytes32 slot = keccak256(abi.encodePacked(asset,year));
        return (Storage.filter(
            slot,
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
        bytes32 slot = keccak256(abi.encodePacked(asset,currentYear));

        return (Storage.filter(
            slot,
            startEpoch, 
            endEpoch));
    } 

    function submitPrices(address asset, uint128 prices) external yearSlot {
        bytes32 slot = keccak256(abi.encodePacked(asset,currentYear));

        Storage.update(slot,prices,uint64(block.timestamp));
    }

}
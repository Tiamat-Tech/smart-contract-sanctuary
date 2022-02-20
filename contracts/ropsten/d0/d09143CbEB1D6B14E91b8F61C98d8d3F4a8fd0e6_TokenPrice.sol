//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract TokenPrice {
    uint32 private constant OFFSET19700101 = 2440588;
    uint32 private constant SECONDS_PER_DAY = 86400;
    string private greeting;
    mapping (uint16 => mapping (uint8 => mapping (uint8 => uint))) public tokenPrices;

    function _daysToDate(uint _days) internal pure returns (uint16 year, uint8 month, uint8 day) {
      uint __days = uint(_days);

      uint L = __days + 68569 + OFFSET19700101;
      uint N = 4 * L / 146097;
      L = L - (146097 * N + 3) / 4;
      uint _year = 4000 * (L + 1) / 1461001;
      L = L - 1461 * _year / 4 + 31;
      uint _month = 80 * L / 2447;
      uint _day = L - 2447 * _month / 80;
      L = _month / 11;
      _month = _month + 2 - 12 * L;
      _year = 100 * (N - 49) + _year + L;

      year = uint16(_year);
      month = uint8(_month);
      day = uint8(_day);
    }

    function setPrice(uint _price, uint16 _year, uint8 _month, uint8 _day) external {
      tokenPrices[_year][_month][_day] = _price;
    }

    function getPrice(uint16 _year, uint8 _month, uint8 _day) external view returns (uint) {
      return tokenPrices[_year][_month][_day];
    }
}
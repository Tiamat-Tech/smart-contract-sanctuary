// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Time is ERC20 {
    struct _DateTime {
        uint16 year;
        uint8 month;
        uint8 day;
        uint8 hour;
        uint8 minute;
        uint8 second;
        uint8 weekday;
    }

    uint256 constant DAY_IN_SECONDS = 86400;
    uint256 constant YEAR_IN_SECONDS = 31536000;
    uint256 constant LEAP_YEAR_IN_SECONDS = 31622400;

    uint256 constant HOUR_IN_SECONDS = 3600;
    uint256 constant MINUTE_IN_SECONDS = 60;

    uint16 constant ORIGIN_YEAR = 1970;
    uint256 lastTimeClaim;
    uint256 timeFrequency;
    address timeGuardian;
    address timeBank; // exchange address
    event RewardSent(
        address timeMiner,
        uint256 reward,
        uint256 timeReleased,
        uint256 gasPrice,
        uint256 startGas,
        uint256 gasFinish,
        uint16 year,
        uint8 month,
        uint8 day
    );
    event Timecycle(uint256 timeFrequency);
    event TimeBankEvent(address timeBank);

    constructor() ERC20("Time", "TIME") {
        lastTimeClaim = block.timestamp;
        timeGuardian = msg.sender;
        timeFrequency = 60;
        _mint(
            address(this),
            (block.timestamp - 1230940800) * 10**uint256(decimals())
        ); // the starting time anniversary
        _burn(
            address(this),
            (block.timestamp - 1230940800) * 10**uint256(decimals())
        );
    }

    function unlockTime() public {
        require(
            (block.timestamp - lastTimeClaim) >= timeFrequency,
            "TIME is released one day every day"
        );
        uint256 startGas = gasleft();
        uint256 reward =
            (block.timestamp - lastTimeClaim - timeFrequency) *
                10**uint256(decimals());
        uint256 timeReleased = timeFrequency * 10**uint256(decimals());
        _mint(timeBank, timeReleased); // Time Contract recieves a day - 5 sec ideally
        _mint(msg.sender, reward); // Time Distributor recieves 5 seconds
        lastTimeClaim = block.timestamp;
        uint256 gasPrice = tx.gasprice;
        uint256 gasFinish = gasleft();
        emit RewardSent(
            msg.sender,
            reward,
            timeReleased,
            gasPrice,
            startGas,
            gasFinish,
            getYear(lastTimeClaim),
            getMonth(lastTimeClaim),
            getDay(lastTimeClaim)
        );
    }

    function setTimeBank(address Bank) public {
        require(msg.sender == timeGuardian, "you are not the Time guardian");
        timeBank = Bank;
        emit TimeBankEvent(timeBank);
    }

    function setTimeFrequency(uint256 frequency) public {
        require(msg.sender == timeGuardian, "you are not the Time guardian");
        timeFrequency = frequency;
        emit Timecycle(timeFrequency);
    }

    function getLastTimeClaim() public view returns (uint256) {
        return lastTimeClaim;
    }

    function getTimeBankAddress() public view returns (address) {
        return timeBank;
    }

    function leapYearsBefore(uint256 year) internal pure returns (uint256) {
        year -= 1;
        return year / 4 - year / 100 + year / 400;
    }

    function isLeapYear(uint16 year) internal pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        }
        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }
        return true;
    }

    function getDaysInMonth(uint8 month, uint16 year)
        internal
        pure
        returns (uint8)
    {
        if (
            month == 1 ||
            month == 3 ||
            month == 5 ||
            month == 7 ||
            month == 8 ||
            month == 10 ||
            month == 12
        ) {
            return 31;
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        } else if (isLeapYear(year)) {
            return 29;
        } else {
            return 28;
        }
    }

    function getMonth(uint256 timestamp) internal pure returns (uint8) {
        return parseTimestamp(timestamp).month;
    }

    function getDay(uint256 timestamp) internal pure returns (uint8) {
        return parseTimestamp(timestamp).day;
    }

    function getHour(uint256 timestamp) internal pure returns (uint8) {
        return uint8((timestamp / 60 / 60) % 24);
    }

    function getMinute(uint256 timestamp) internal pure returns (uint8) {
        return uint8((timestamp / 60) % 60);
    }

    function getSecond(uint256 timestamp) internal pure returns (uint8) {
        return uint8(timestamp % 60);
    }

    function getWeekday(uint256 timestamp) internal pure returns (uint8) {
        return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
    }

    function parseTimestamp(uint256 timestamp)
        internal
        pure
        returns (_DateTime memory dt)
    {
        uint256 secondsAccountedFor = 0;
        uint256 buf;
        uint8 i;

        // Year
        dt.year = getYear(timestamp);
        buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
        secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

        // Month
        uint256 secondsInMonth;
        for (i = 1; i <= 12; i++) {
            secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
            if (secondsInMonth + secondsAccountedFor > timestamp) {
                dt.month = i;
                break;
            }
            secondsAccountedFor += secondsInMonth;
        }

        // Day
        for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
            if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
                dt.day = i;
                break;
            }
            secondsAccountedFor += DAY_IN_SECONDS;
        }

        // Hour
        dt.hour = getHour(timestamp);

        // Minute
        dt.minute = getMinute(timestamp);

        // Second
        dt.second = getSecond(timestamp);

        // Day of week.
        dt.weekday = getWeekday(timestamp);
    }

    function getYear(uint256 timestamp) internal pure returns (uint16) {
        uint256 secondsAccountedFor = 0;
        uint16 year;
        uint256 numLeapYears;

        // Year
        year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
        numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
        secondsAccountedFor +=
            YEAR_IN_SECONDS *
            (year - ORIGIN_YEAR - numLeapYears);

        while (secondsAccountedFor > timestamp) {
            if (isLeapYear(uint16(year - 1))) {
                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
            } else {
                secondsAccountedFor -= YEAR_IN_SECONDS;
            }
            year -= 1;
        }
        return year;
    }
}
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/proxy/Initializable.sol";

contract Demo is Initializable {
    uint256 week;

    function initialize(uint256 _x) public initializer {
        week = _x;
    }

    function getDaysInMonth() public pure returns (uint256) {
        return 30;
    }

    function getWeek() public view returns (uint256) {
        return week;
    }
}
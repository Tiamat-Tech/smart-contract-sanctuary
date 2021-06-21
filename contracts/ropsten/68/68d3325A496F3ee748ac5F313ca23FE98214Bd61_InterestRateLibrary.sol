// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";

contract InterestRateLibrary is Ownable {
    // interest rate percent per year => interest rate percent per second
    mapping(uint256 => uint256) public ratesPerSecond;

    uint256 public maxSupportedPercentage;

    constructor(uint256[] memory _ratesPerSecond) Ownable() {
        _addRates(0, _ratesPerSecond);
    }

    function addNewRates(uint256 _startPercentage, uint256[] memory _ratesPerSecond)
        external
        onlyOwner
    {
        require(
            _startPercentage == maxSupportedPercentage + 1,
            "InterestRateLibrary: Incorrect starting percentage to add."
        );

        _addRates(_startPercentage, _ratesPerSecond);
    }

    function _addRates(uint256 _startPercentage, uint256[] memory _ratesPerSecond) internal {
        uint256 _listLength = _ratesPerSecond.length;

        for (uint256 i = 0; i < _listLength; i++) {
            ratesPerSecond[_startPercentage + i] = _ratesPerSecond[i];
        }

        maxSupportedPercentage = _startPercentage + _listLength - 1;
    }
}
/*
 SPDX-License-Identifier: MIT
*/

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {AppStorage} from "../AppStorage.sol";

/**
 * @author Publius
 * @title InitSetWeather
**/

interface IBs {
    function updateSilo(address account) external;
}

contract InitSetWeather {
    AppStorage internal s;

    function init() external {
        s.season.withdrawSeasons = 5;
    }
}
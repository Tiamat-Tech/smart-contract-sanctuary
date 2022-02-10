//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '../utils/Constants.sol';
import './CurveConvexStrat2.sol';

contract USDPCurveConvex is CurveConvexStrat2 {
    constructor()
        CurveConvexStrat2(
            Constants.USDT_ADDRESS,
            Constants.USDT_ADDRESS,
            Constants.USDT_ADDRESS,
            5,
            Constants.USDT_ADDRESS,
            Constants.USDT_ADDRESS,
            Constants.USDT_ADDRESS
        )
    {}
}
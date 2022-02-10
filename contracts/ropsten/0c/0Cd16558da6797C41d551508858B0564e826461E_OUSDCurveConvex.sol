//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '../utils/Constants.sol';
import './CurveConvexStrat2.sol';

contract OUSDCurveConvex is CurveConvexStrat2 {
    constructor()
        CurveConvexStrat2(
            Constants.USDT_ADDRESS,
            Constants.USDT_ADDRESS,
            Constants.USDT_ADDRESS,
            4,
            Constants.USDT_ADDRESS,
            Constants.USDT_ADDRESS,
            Constants.USDT_ADDRESS
        )
    {}
}
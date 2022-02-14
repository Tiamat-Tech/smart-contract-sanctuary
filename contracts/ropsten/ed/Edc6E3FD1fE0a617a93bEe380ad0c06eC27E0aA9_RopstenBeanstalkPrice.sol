//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./RopstenCurvePrice.sol";
import "./RopstenUniswapPrice.sol";

contract RopstenBeanstalkPrice is RopstenUniswapPrice, RopstenCurvePrice {

    using SafeMath for uint256;

    struct Prices {
        uint256 price;
        uint256 liquidity;
        int deltaB;
        P.Pool[2] ps;
    }

    function price() external view returns (Prices memory p) {
        P.Pool memory c = getCurve();
        P.Pool memory u = getUniswap();
        p.ps = [c,u];
        p.price = (c.price*c.liquidity + u.price*u.liquidity) / (c.liquidity + u.liquidity);
        p.liquidity = c.liquidity + u.liquidity;
        p.deltaB = c.deltaB + u.deltaB;
    }
}
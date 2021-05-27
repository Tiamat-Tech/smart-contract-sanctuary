//contracts/BondingCurve/LinearBondingCurve.sol
//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import "./BondingCurve.sol";

contract LinearBondingCurve is BondingCurve {
    using SafeERC20 for IERC20;
    uint256 internal immutable K;
    uint256 internal immutable START_PRICE;

    constructor(
        IERC20 _token,
        uint256 _k,
        uint256 _startPrice
    ) BondingCurve(_token) {
        K = _k;
        START_PRICE = _startPrice;
    }

    function s(uint256 x0, uint256 x1) public view override returns (uint256) {
        require(x1 > x0);
        return (((x1 + x0) * ( x1 - x0) ) / (K * 2) + (START_PRICE * ( x1 - x0) )) / (1e18);
        // return x1.add(x0).mul(x1.sub(x0))
        //     .div(2).div(K)
        //     .add(START_PRICE.mul(x1.sub(x0)))
        //     .div(1e18);
    }
}
//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "../references/hoge.finance.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HogeFactory {
    // address public constant VAULT = ;
    address public constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address public constant DAI = 0xaD6D458402F60fD3Bd25163575031ACDce07538D;

    constructor() {
        HOGE hogeLaunch = new HOGE();
        // address 1 burn address.
        uint256 halfBurnOnLaunch = SafeMath.div(hogeLaunch.balanceOf(address(this)), 2);
        hogeLaunch.approve(address(1), halfBurnOnLaunch);
        hogeLaunch.transfer(address(1), halfBurnOnLaunch);
        hogeLaunch.transferOwnership(msg.sender);
        // timeMintCoin.createPool(timeMintCoin.DAI());
    }

}
